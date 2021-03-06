# frozen_string_literal: true

module Nanoc::Int
  # Represents a cache than can be used to store already compiled content,
  # to prevent it from being needlessly recompiled.
  #
  # @api private
  class BinaryContentCache < ::Nanoc::Int::Store
    include Nanoc::Int::ContractsSupport

    contract C::KeywordArgs[config: Nanoc::Int::Configuration] => C::Any
    def initialize(config:)
      super(Nanoc::Int::Store.tmp_path_for(config: config, store_name: 'binary_content'), 1)
    end

    contract Nanoc::Int::ItemRep => C::Maybe[C::HashOf[Symbol => Nanoc::Int::Content]]
    # Returns the cached compiled content for the given item representation.
    #
    # This cached compiled content is a hash where the keys are the snapshot
    # names. and the values the compiled content at the given snapshot.
    def [](rep)
      cached = file_for(rep)
      return nil unless File.directory?(cached)

      Dir["#{cached}/*"]
        .select { |e| File.file?(e) }
        .each_with_object({}) do |f, memo|
          memo[File.basename(f).to_sym] = Nanoc::Int::Content.create(f, binary: true)
        end
    end

    contract Nanoc::Int::ItemRep, C::HashOf[Symbol => Nanoc::Int::Content] => C::HashOf[Symbol => Nanoc::Int::Content]
    # Sets the compiled content for the given representation.
    #
    # This cached compiled content is a hash where the keys are the snapshot
    # names. and the values the compiled content at the given snapshot.
    def []=(rep, content)
      binaries = rep.snapshot_defs.select(&:binary?).map(&:name)

      content
        .select { |snapshot, _| binaries.include?(snapshot) }
        .each do |snapshot, content|
        cached = file_for(rep, snapshot: snapshot)

        next if File.identical?(content.filename, cached)

        FileUtils.mkdir_p(File.dirname(cached))
        FileUtils.cp(content.filename, cached)
      end
    end

    def prune(items:)
      kept_dirs = Set.new(items.map(&:identifier))
                     .map { |i| File.join(filename, i) }

      extra = Dir["#{filename}/**/*"]
        .select { |e| File.directory?(e) }
        .reject { |f| kept_dirs.any? { |k| f.start_with?(k) } }
        .reject { |d| Dir["#{d}/*"].select { |e| File.file?(e) }.empty? }

      extra.each { |f| FileUtils.rm_rf(f) }
    end

    def load(*args)
    end

    def store(*args)
    end

    private

    def file_for(rep, snapshot: '')
      File.join(filename, rep.item.identifier.to_s, rep.name.to_s, snapshot.to_s)
    end
  end
end
