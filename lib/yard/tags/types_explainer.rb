require 'strscan'

module YARD
  module Tags
    class TypesExplainer
      # (see Tag#explain_types)
      # @param types [Array<String>] a list of types to parse and summarize
      def self.explain(*types)
        explain!(*types)
      rescue SyntaxError
        nil
      end

      # (see explain)
      # @raise [SyntaxError] if the types are not parseable
      def self.explain!(*types)
        Parser.parse(types.join(", ")).join("; ")
      end

      class << self
        private :new
      end


      # @private
      class Type
        attr_accessor :name
        
        def initialize(name)
          @name = name
        end
        
        def to_s(singular = true)
          if name[0, 1] == "#"
            singular ? "an object that responds to #{name}" : "objects that respond to #{name}"
          elsif name[0, 1] =~ /[A-Z]/
            singular ? "a#{name[0, 1] =~ /[aeiou]/i ? 'n' : ''} " + name : "#{name}#{name[-1, 1] =~ /[A-Z]/ ? "'" : ''}s"
          else
            name
          end
        end

        private

        def list_join(list)
          index = 0
          list.inject("") do |acc, el|
            acc << el.to_s
            acc << ", " if index < list.size - 2
            acc << " or " if index == list.size - 2
            index += 1
            acc
          end
        end
      end

      # @private
      class CollectionType < Type
        attr_accessor :types
        
        def initialize(name, types)
          @name = name
          @types = types
        end
        
        def to_s(singular = true)
          "a#{name[0, 1] =~ /[aeiou]/i ? 'n' : ''} #{name} of (" + list_join(types.map {|t| t.to_s(false) }) + ")"
        end
      end

      # @private
      class FixedCollectionType < CollectionType
        def to_s(singular = true)
          "a#{name[0, 1] =~ /[aeiou]/i ? 'n' : ''} #{name} containing (" + types.map(&:to_s).join(" followed by ") + ")"
        end
      end

      # @private
      class HashCollectionType < Type
        attr_accessor :key_types, :value_types
        
        def initialize(name, key_types, value_types)
          @name = name
          @key_types = key_types
          @value_types = value_types
        end
        
        def to_s(singular = true)
          "a#{name[0, 1] =~ /[aeiou]/i ? 'n' : ''} #{name} with keys made of (" + list_join(key_types.map {|t| t.to_s(false) }) + 
          ") and values of (" + list_join(value_types.map {|t| t.to_s(false) }) + ")"
        end
      end

      # @private
      class Parser
        TOKENS = {
          :collection_start => /</,
          :collection_end => />/,
          :fixed_collection_start => /\(/,
          :fixed_collection_end => /\)/,
          :type_name => /#\w+|((::)?\w+)+/,
          :type_next => /[,;]/,
          :whitespace => /\s+/,
          :hash_collection_start => /\{/,
          :hash_collection_next => /=>/,
          :hash_collection_end => /\}/,
          :parse_end => nil
        }
        
        def self.parse(string)
          new(string).parse
        end
        
        def initialize(string)
          @scanner = StringScanner.new(string)
        end
        
        def parse
          types = []
          type = nil
          fixed = false
          name = nil
          loop do
            found = false
            TOKENS.each do |token_type, match|
              if (match.nil? && @scanner.eos?) || (match && token = @scanner.scan(match))
                found = true
                case token_type
                when :type_name
                  raise SyntaxError, "expecting END, got name '#{token}'" if name
                  name = token
                when :type_next
                  raise SyntaxError, "expecting name, got '#{token}' at #{@scanner.pos}" if name.nil?
                  unless type
                    type = Type.new(name)
                  end
                  types << type
                  type = nil
                  name = nil
                when :fixed_collection_start, :collection_start
                  name ||= "Array"
                  klass = token_type == :collection_start ? CollectionType : FixedCollectionType
                  type = klass.new(name, parse)
                when :hash_collection_start
                  name ||= "Hash"
                  type = HashCollectionType.new(name, parse, parse)
                when :hash_collection_next, :hash_collection_end, :fixed_collection_end, :collection_end, :parse_end
                  raise SyntaxError, "expecting name, got '#{token}'" if name.nil?
                  unless type
                    type = Type.new(name)
                  end
                  types << type 
                  return types
                end
              end
            end
            raise SyntaxError, "invalid character at #{@scanner.peek(1)}" unless found
          end
        end
      end
    end
  end
end
