module Deferring
  module Matchers

    class ArQuery  #:nodoc:
      cattr_accessor :executed

      @@recording_queries = false
      def self.recording_queries?
        @@recording_queries
      end

      def initialize(expected, &block)
        @expected = expected
        @block = block
      end

      def matches?(given_proc)
        @eval_block = false
        @eval_error = nil
        ArQuery.executed = []
        @@recording_queries = true

        given_proc.call

        if @expected.is_a?(Integer)
          @actual = ArQuery.executed.length
          @matched = @actual == @expected
        else
          @actual = ArQuery.executed.detect { |sql| @expected === sql }
          @matched = !@actual.nil?
        end

        eval_block if @block && @matched && !negative_expectation?

      ensure
        ArQuery.executed = nil
        @@recording_queries = false
        return @matched && @eval_error.nil?
      end

      def eval_block
        @eval_block = true
        begin
          @block[ArQuery.executed]
        rescue => err
          @eval_error = err
        end
      end

      def supports_block_expectations?
        true
      end

      def failure_message
        if @eval_error
          @eval_error.message
        elsif @expected.is_a?(Integer)
          "expected #{@expected}, got #{@actual}"
        else
          "expected to execute a query with pattern #{@expected.inspect}, but it wasn't"
        end
      end

      def failure_message_when_negated
        if @expected.is_a?(Integer)
          "did not expect #{@expected}"
        else
          "did not expect to execute a query with pattern #{@expected.inspect}, but it was executed"
        end
      end

      def description
        if @expected.is_a?(Integer)
          @expected == 1 ? 'execute 1 query' : "execute #{@expected} queries"
        else
          "execute query with pattern #{@expected.inspect}"
        end
      end

      def negative_expectation?
        @negative_expectation ||= !caller.first(3).find { |s| s =~ /should_not/ }.nil?
      end
    end

    def query(expected = 1, &block)
      ArQuery.new(expected, &block)
    end
  end
end

# For Rails 6.0
module ActiveRecord
  module ConnectionAdapters
    module SQLite3
      module DatabaseStatements
        [:exec_query, :exec, :execute].each do |method|
          if respond_to?(method)
            define_method("#{method}_with_query_record") do |sql, *args|
              Deferring::Matchers::ArQuery.executed << sql if Deferring::Matchers::ArQuery.recording_queries?
              send("#{method}_without_query_record", sql, *args)
            end

            alias_method :"#{method}_without_query_record", method
            alias_method method, :"#{method}_with_query_record"
          end
        end
      end
    end
  end
end

# For previous versions of Rails
module ActiveRecord
  module ConnectionAdapters
    class SQLite3Adapter
      [:exec_query, :exec, :execute].each do |method|
        define_method("#{method}_with_query_record") do |sql, *args|
          Deferring::Matchers::ArQuery.executed << sql if Deferring::Matchers::ArQuery.recording_queries?
          send("#{method}_without_query_record", sql, *args)
        end

        alias_method :"#{method}_without_query_record", method
        alias_method method, :"#{method}_with_query_record"
      end
    end
  end
end
