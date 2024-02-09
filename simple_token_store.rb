# frozen_string_literal: true

module Sheety
  class SimpleTokenStore < Google::Auth::TokenStore
    DEFAULT_ID = "default"

    def initialize(token, &on_store)
      @token = token
      @on_store = on_store
    end

    def guard_id(id)
      raise "Only implemented for default token" unless id == DEFAULT_ID
    end

    def load(id)
      guard_id(id)
      @token
    end

    def store(id, token)
      guard_id(id)
      @on_store&.call(token, @token)
      @token = token
    end

    def delete(_id)
      raise NotImplemented
    end
  end
end
