# frozen_string_literal: true

module Nanoc::Int
  # Represents a cache than can be used to store already compiled content,
  # to prevent it from being needlessly recompiled.
  #
  # @api private
  class CompositeCache < ::Nanoc::Int::Store
    include Nanoc::Int::ContractsSupport

    contract C::KeywordArgs[config: Nanoc::Int::Configuration] => C::Any
    def initialize(config:)
      @textual = Nanoc::Int::CompiledContentCache.new(config: config)
      @binary = Nanoc::Int::BinaryContentCache.new(config: config)

      @wrapped = [@textual, @binary]
    end

    contract Nanoc::Int::ItemRep => C::Maybe[C::HashOf[Symbol => Nanoc::Int::Content]]
    # Returns the cached compiled content for the given item representation.
    #
    # This cached compiled content is a hash where the keys are the snapshot
    # names. and the values the compiled content at the given snapshot.
    def [](rep)
      # require 'awesome_print' rescue nil; require 'pry-byebug'; binding.pry
      textual = (@textual[rep] || {}).reject { |_, content| content.binary? }
      binary = (@binary[rep] || {}).select { |_, content| content.binary? }

      cache = textual.merge(binary)

      # Ensure all snapshot keys exist in the composed cache.
      return nil if cache.empty?

      return cache if rep.snapshot_defs.map(&:name).all? { |snapshot| cache.key?(snapshot) }

      nil
    end

    contract Nanoc::Int::ItemRep, C::HashOf[Symbol => Nanoc::Int::Content] => C::HashOf[Symbol => Nanoc::Int::Content]
    # Sets the compiled content for the given representation.
    #
    # This cached compiled content is a hash where the keys are the snapshot
    # names. and the values the compiled content at the given snapshot.
    def []=(rep, content)
      @wrapped.each { |c| c[rep] = content }

      content
    end

    def prune(*args)
      @wrapped.each { |w| w.prune(*args) }
    end

    def load(*args)
      @wrapped.each { |w| w.load(*args) }
    end

    def store(*args)
      @wrapped.each { |w| w.store(*args) }
    end

    private

    def target(rep)
      return @binary if rep.item.content.binary? # rep.snapshot_defs!

      @textual
    end
  end
end
