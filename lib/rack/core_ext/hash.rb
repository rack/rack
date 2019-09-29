# frozen_string_literal: true

# Hash has `transform_keys` since Ruby 2.5.
# For Ruby < 2.5, we need to add the following

module Rack
  module HashExtensions
    refine Hash do
      def transform_keys(&block)
        hash = {}
        each do |key, value|
          hash[block.call(key)] = value
        end
        hash
      end unless {}.respond_to?(:transform_keys)
    end
  end
end

