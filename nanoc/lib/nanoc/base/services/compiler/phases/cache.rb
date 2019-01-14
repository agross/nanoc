# frozen_string_literal: true

module Nanoc::Int::Compiler::Phases
  # Provides functionality for (re)calculating the content of an item rep, with caching or
  # outdatedness checking. Delegates to s::Recalculate if outdated or no cache available.
  class Cache < Abstract
    include Nanoc::Int::ContractsSupport

    def initialize(wrapped:, compiled_content_cache:, compiled_content_store:)
      super(wrapped: wrapped)

      @compiled_content_cache = compiled_content_cache
      @compiled_content_store = compiled_content_store
    end

    contract Nanoc::Int::ItemRep, C::KeywordArgs[is_outdated: C::Bool], C::Func[C::None => C::Any] => C::Any
    def run(rep, is_outdated:)
      if can_reuse_content_for_rep?(rep, is_outdated: is_outdated)
        Nanoc::Int::NotificationCenter.post(:cached_content_used, rep)

        @compiled_content_store.set_all(rep, @compiled_content_cache[rep])
      else
        yield
      end

      rep.compiled = true
      @compiled_content_cache[rep] = @compiled_content_store.get_all(rep)
    end

    contract Nanoc::Int::ItemRep, C::KeywordArgs[is_outdated: C::Bool] => C::Bool
    def can_reuse_content_for_rep?(rep, is_outdated:)
      if is_outdated
        false
      else
        !!@compiled_content_cache[rep]
      end
    end
  end
end
