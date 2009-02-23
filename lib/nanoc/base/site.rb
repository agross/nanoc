module Nanoc

  # A Nanoc::Site is the in-memory representation of a nanoc site. It holds
  # references to the following site data:
  #
  # * +pages+ is a list of Nanoc::Page instances representing pages
  # * +assets+ is a list of Nanoc::Asset instances representing assets
  # * +layouts+ is a list of Nanoc::Layout instances representing layouts
  # * +code+ is a Nanoc::Code instance representing custom site code
  #
  # In addition, each site has a +config+ hash which stores the site
  # configuration. This configuration hash can have the following keys:
  #
  # +output_dir+:: The directory to which compiled pages and assets will be
  #                written. This path is relative to the current working
  #                directory, but can also be an absolute path.
  #
  # +data_source+:: The identifier of the data source that will be used for
  #                 loading site data.
  #
  # +router+:: The identifier of the router that will be used for determining
  #            page and asset representation paths.
  #
  # +index_filenames+:: A list of filenames that will be stripped off full
  #                     page and asset paths to create cleaner URLs (for
  #                     example, '/about/' will be used instead of
  #                     '/about/index.html'). The default value should be okay
  #                     in most cases.
  #
  # A site also has several helper classes:
  #
  # * +router+ is a Nanoc::Router subclass instance used for determining page
  #   and asset paths.
  # * +data_source+ is a Nanoc::DataSource subclass instance used for managing
  #   site data.
  # * +compiler+ is a Nanoc::Compiler instance that compiles page and asset
  #   representations.
  #
  # The physical representation of a Nanoc::Site is usually a directory that
  # contains a configuration file, site data, and some rake tasks. However,
  # different frontends may store data differently. For example, a web-based
  # frontend would probably store the configuration and the site content in a
  # database, and would not have rake tasks at all.
  class Site

    # The default configuration for a site. A site's configuration overrides
    # these options: when a Nanoc::Site is created with a configuration that
    # lacks some options, the default value will be taken from
    # +DEFAULT_CONFIG+.
    DEFAULT_CONFIG = {
      :output_dir       => 'output',
      :data_source      => 'filesystem',
      :router           => 'default',
      :index_filenames  => [ 'index.html' ]
    }

    attr_reader :config
    attr_reader :compiler, :data_source, :router
    attr_reader :pages, :assets, :layouts, :code

    # Returns a Nanoc::Site object for the site specified by the given
    # configuration hash +config+.
    #
    # +config+:: A hash containing the site configuration.
    def initialize(config, params={})
      # Load configuration
      @config = DEFAULT_CONFIG.merge(config.clean)

      # Create data source
      @data_source_class = Nanoc::DataSource.named(@config[:data_source])
      raise Nanoc::Errors::UnknownDataSourceError.new(@config[:data_source]) if @data_source_class.nil?
      @data_source = @data_source_class.new(self)

      # Create compiler
      @compiler = Compiler.new(self)

      # Load code (necessary for custom routers)
      load_code

      # Create router
      @router_class = Nanoc::Router.named(@config[:router])
      raise Nanoc::Errors::UnknownRouterError.new(@config[:router]) if @router_class.nil?
      @router = @router_class.new(self)

      # Initialize data
      @pages   = []
      @assets  = []
      @layouts = []
      load_data if params[:load_data] || !params.has_key?(:load_data)
    end

    # Loads the site data. This will query the Nanoc::DataSource associated
    # with the site and fetch all site data. The site data is cached, so
    # calling this method will not have any effect the second time, unless
    # +force+ is true.
    #
    # +force+:: If true, will force load the site data even if it has been
    #           loaded before, to circumvent caching issues.
    def load_data(force=false)
      # Don't load data twice
      @data_loaded ||= false
      return if @data_loaded and !force

      # Load all data
      @data_source.loading do
        load_code(force)
        load_pages
        load_assets
        load_layouts
      end
      @data_loaded = true
    end

  private

    # Loads this site's code and executes it.
    def load_code(force=false)
      # Don't load code twice
      @code_loaded ||= false
      return if @code_loaded and !force

      # Get code
      @code = @data_source.code
      @code.site = self

      # Execute code
      @code.load
      @code_loaded = true
    end

    # Loads this site's pages, sets up page child-parent relationships and
    # builds each page's list of page representations.
    def load_pages
      @pages = @data_source.pages
      @pages.each { |p| p.site = self }

      # Setup child-parent links
      @pages.each do |page|
        # Get parent
        parent_identifier = page.identifier.sub(/[^\/]+\/$/, '')
        parent = @pages.find { |p| p.identifier == parent_identifier }
        next if parent.nil? or page.identifier == '/'

        # Link
        page.parent = parent
        parent.children << page
      end
    end

    # Loads this site's assets and builds each asset's list of asset
    # representations.
    def load_assets
      @assets = @data_source.assets
      @assets.each { |a| a.site = self }
    end

    # Loads this site's layouts.
    def load_layouts
      @layouts = @data_source.layouts
      @layouts.each { |l| l.site = self }
    end

  end

end
