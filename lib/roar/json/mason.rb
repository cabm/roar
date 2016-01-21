require 'roar/json'
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
          include Roar::JSON
          include Links       # overwrites #links_definition_options.
          include Roar::Hypermedia
          include Resources
        end
      end
      module Resources
      # remove the nested namespaces from each of the results
        def to_hash(*args)
          results = super
          results.each do |key, value|
            next if key.start_with?('@')
            next unless value.is_a?(Array)
            value.each do |element|
              begin
                next if element['@namespaces'].nil?
              rescue TypeError
                next
              end
              results['@namespaces'] ||= {}
              results['@namespaces'].merge! element['@namespaces']
              element.delete '@namespaces'
            end
          end
          results
        end
      end
      module Links
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
            curies_configs = representable_attrs["curies"].link_configs
            compile_curies_for(curies_configs, options)
          end

          def prepare_meta!(options)
            return [] if options[:meta] == false
            meta_configs = representable_attrs["meta"].link_configs
            compile_metas_for(meta_configs, options)
          end

          def compile_metas_for(configs, *args)
            configs.collect do |config|
              options, block  =  config.first, config.last
              href            = run_link_block(block, *args) or next
              prepare_meta_for(href, options)
            end.compact # FIXME: make this less ugly.
          end

          def prepare_meta_for(name, options)
            options = options.merge({:name => name})
            Hypermedia::Hyperlink.new(options)
          end
        end

        class SingleLink
          class Representer < Representable::Decorator
            include Representable::JSON::Hash

            def to_hash(*)
              hash = super
              {hash.delete("rel").to_s => hash}
            end
          end
        end


        # Represents all links for  "@controls":  [Hyperlink, Hyperlink, Hyperlink]
        class Representer < Representable::Decorator # links could be a simple collection property.
          include Representable::JSON::Collection

          # render: decorates represented.links with ArrayLink::R or SingleLink::R and calls #to_hash.
          # parse:  instantiate either Array or Hypermedia instance, decorate respectively, call #from_hash.
          items decorator: ->(options) { SingleLink::Representer },
                class:     ->(options) { Hypermedia::Hyperlink }

          def to_hash(options)
            links = {}
            super.each { |hash| links.merge!(hash) } # [{ rel=>{} }]
            links
          end

          def from_hash(hash, *args)
            collection = hash.collect do |rel, value| # "self" => {"href": "//"}
              value.merge("rel"=>rel)
            end

            super(collection) # {rel=>self, href=>//}
          end
        end


        module ClassMethods
          def links_definition_options
            {
              :as       => :@controls,
              decorator: Links::Representer,
              instance: ->(*) { Array.new }, # defined in InstanceMethods as this is executed in represented context.
              :exec_context => :decorator,
            }
          end

          def curies_definition_options
            {
              as: :@namespaces,
              decorator: Links::Representer,
              instance: ->(*) { Array.new },
              exec_context: :decorator
            }
          end

          def create_curies_definition!
            dfn = definitions["curies"] and return dfn # only create it once.

            options = curies_definition_options
            options.merge!(getter: ->(options) { prepare_curies!(options) })

            dfn = build_definition(:curies, options)
            dfn.extend(Roar::Hypermedia::DefinitionOptions)
            dfn

          end

          # Add a CURIEs link section as defined in
          #
          # curies :doc do
          #    "//docs/{rel}",
          # end

          def curies(key, &block)
            create_curies_definition!
            options = {:rel => key}
            representable_attrs["curies"].link_configs << [options, block]
          end

          def meta(key, &block)
            create_meta_definition!
            options = {:rel => key}
            representable_attrs["meta"].link_configs << [options, block]
          end

          def create_meta_definition!

            dfn = definitions["meta"] and return dfn # only create it once.
            options = meta_definition_options
            options.merge!(getter: ->(options) { prepare_meta!(options) })

            dfn = build_definition(:meta, options)
            dfn.extend(Roar::Hypermedia::DefinitionOptions)
            dfn

          end

          def meta_definition_options
            {
              as: :@meta,
              decorator: Links::Representer,
              instance: ->(*) { Array.new },
              exec_context: :decorator
            }
          end
        end
      end
    end
  end
end
