require 'roar/json'
require 'pry'
require 'roar/json/hal'

module Roar
  module JSON
    # Including the JSON::Mason module in your representer will render and parse documents
    # following the Mason draft 2 specification: https://github.com/JornWildt/Mason/blob/master/Documentation/Mason-draft-2.md
    #
    # TODO: document how links, curies and <TBD> can be called to generate and consume Mason format
    # NOTE: Used HAL code as a template for creating the Mason format for Roar :)

    module Mason
      def self.included(base)
        base.class_eval do
          include Roar::JSON::HAL
          include Roar::JSON::HAL::Links
          include Controls  # overwrites #links_definition_options.
        end
      end

      module ClassMethods
        def links_definition_options
          super.merge(:as => :@controls)
        end
      end

      # Including this module in your representer will render and parse your hyperlinks
      # following the Mason draft 2 specification:
      #     https://github.com/JornWildt/Mason/blob/master/Documentation/Mason-draft-2.md
      #
      #   module SongRepresenter
      #     include Roar::JSON
      #     include Roar::JSON::Mason::Controls
      #
      #     link :self { "http://self" }
      #   end
      #
      # Renders to
      #
      #   {"@controls":{"self":{"href":"http://self"}}}
      #
      module Controls
        def self.included(base)
          base.extend ClassMethods  # ::links_definition_options
          base.send :include, Hypermedia
          base.send :include, InstanceMethods
        end

        module InstanceMethods
        private
          def compile_curies_for(configs, *args)
            configs.collect do |config|
              options, block  = config.first, config.last
              href            = run_link_block(block, *args) or next

              prepare_curie_for(href, options)
            end.compact # FIXME: make this less ugly.
          end
          
          def prepare_curie_for(name, options)
            options = options.merge({:name => name})
            Hypermedia::Hyperlink.new(options)
          end
        
          def prepare_curies!(options)
            return [] if options[:curies] == false
            Roar::JSON::HAL::LinkCollection[*compile_curies_for((representable_attrs[:curies] ||= Representable::Inheritable::Array.new), options)]
          end
          
        end

        module ClassMethods
          def links_definition_options
            # property :links_array,
            {
              :as       => :@controls,
              :extend   => Roar::JSON::HAL::Links::LinkCollectionRepresenter,
              :instance => lambda { |*| Roar::JSON::HAL::LinkCollection.new({}) }, # defined in InstanceMethods as this is executed in represented context.
              :exec_context => :decorator,
            }
          end

          # Use this to define link arrays. It accepts the shared rel attribute and an array of options per link object.
          #
          #   controls :self do
          #     [{:lang => "en", :href => "http://en.hit"},
          #      {:lang => "de", :href => "http://de.hit"}]
          #   end
          def controls(options, &block)
            options = {:rel => options} if options.is_a?(Symbol)
            options[:array] = true
            link(options, &block)
          end

          # Add a curies link section as defined in
          #
          # curies do
          #   "name" => "//docs/{rel}"
          # end

          def curies(key, &block)
            create_curies_definition!
            options = {:rel => key}
            curie_configs << [options, block]
          end

          def curie_configs
            representable_attrs[:curies] ||= Representable::Inheritable::Array.new
          end

          def create_curies_definition!
            return if representable_attrs.get(:curies) # only create it once.
            options = curies_definition_options

            options.merge!(:getter => lambda { |opts| prepare_curies!(opts) })
            representable_attrs.add(:curies, options)
          end

          def curies_definition_options
            {
              :as       => :@namespaces,
              :extend   => Roar::JSON::HAL::Links::LinkCollectionRepresenter,
              :instance => lambda { |*| Roar::JSON::HAL::LinkCollection.new({}) }, # defined in InstanceMethods as this is executed in represented context.
              :exec_context => :decorator,
           }
          end

        end
      end
    end
  end
end
