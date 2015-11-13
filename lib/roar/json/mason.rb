require 'roar/json'
require 'pry'

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
          include Controls       # overwrites #links_definition_options.
          extend ClassMethods # overwrites #links_definition_options, again.
          include Resources
        end
      end

      module Resources
        def to_hash(*)
          super.tap do |hash|
            embedded = {}
            representable_attrs.find_all do |dfn|
              name = dfn[:as].(nil) # DISCUSS: should we simplify that in Representable?
              next unless dfn[:embedded] and fragment = hash.delete(name)
              embedded[name] = fragment
            end

            hash["_embedded"] = embedded if embedded.any?
            hash["_links"]    = hash.delete("_links") if hash["_links"] # always render _links after _embedded.
          end
        end

        def from_hash(hash, *)
          hash.fetch("_embedded", []).each { |name, fragment| hash[name] = fragment }
          super
        end
      end

      module ClassMethods
        def links_definition_options
          super.merge(:as => :@controls)
        end
      end

      class LinkCollection < Hypermedia::LinkCollection
        def initialize(array_rels, *args)
          super(*args)
          @array_rels = array_rels.map(&:to_s)
        end

        def is_array?(rel)
          @array_rels.include?(rel.to_s)
        end

        def create_curies_definition!
            return if representable_attrs.get(:curies) # only create it once.
            options = curies_definition_options


            #options.merge!(:getter => lambda { |opts| LinkCollection[*compile_links_for(( representable_attrs[:curies] ||= Representable::Inheritable::Array.new), options)] })
            options.merge!(:getter => lambda { |opts| prepare_curies!(opts) })
            representable_attrs.add(:curies, options)
        end

        # Add a curies link section as defined in
          #
          # curies do
          #   "name" => "//docs/{rel}"
          # end

        def curie(&block)
          create_curies_definition!
          options = {:rel => :is}
          curie_configs << [options, block]
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
          def prepare_link_for(href, options)
            return super(href, options) unless options[:array]  # TODO: remove :array and use special instan

            list = href.collect { |opts| Hypermedia::Hyperlink.new(opts.merge!(:rel => options[:rel])) }
            LinkArray.new(list, options[:rel])
          end

          # TODO: move to LinksDefinition.
          def link_array_rels
            link_configs.collect { |cfg| cfg.first[:array] ? cfg.first[:rel] : nil }.compact
          end
        end

        require 'representable/json/hash'
        module LinkCollectionRepresenter
          include Representable::JSON::Hash

          values :extend => lambda { |item, *|
            item.is_a?(Array) ? LinkArrayRepresenter : Roar::JSON::HyperlinkRepresenter },
            :instance => lambda { |fragment, *| fragment.is_a?(LinkArray) ? fragment : Roar::Hypermedia::Hyperlink.new
          }

          def to_hash(options)
            super.tap do |hsh|  # TODO: cool: super(:exclude => [:rel]).
              hsh.each { |k,v| v.delete("rel") }
            end
          end

          def from_hash(hash, *args)
            hash.each { |k,v| hash[k] = LinkArray.new(v, k) if is_array?(k) }

            hsh = super(hash) # this is where :class and :extend do the work.

            hsh.each { |k, v| v.merge!(:rel => k) }
            hsh.values # links= expects [Hyperlink, Hyperlink]
          end
        end

        # DISCUSS: we can probably get rid of this asset.
        class LinkArray < Array
          def initialize(elems, rel)
            super(elems)
            @rel = rel
          end

          attr_reader :rel

          def merge!(attrs)
            each { |lnk| lnk.merge!(attrs) }
          end
        end

        require 'representable/json/collection'
        module LinkArrayRepresenter
          include Representable::JSON::Collection

          items :extend => Roar::JSON::HyperlinkRepresenter,
            :class => Roar::Hypermedia::Hyperlink

          def to_hash(*)
            super.tap do |ary|
              ary.each { |lnk| rel = lnk.delete("rel") }
            end
          end
        end

        module ClassMethods
          def links_definition_options
            # property :links_array,
            {
              :as       => :@controls,
              :extend   => Mason::Controls::LinkCollectionRepresenter,
              :instance => lambda { |*| LinkCollection.new(link_array_rels) }, # defined in InstanceMethods as this is executed in represented context.
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

          def curie_configs
            representable_attrs[:curies] ||= Representable::Inheritable::Array.new
          end

          # Needed for cleanup in create_curies_definition! method
          #
          def prepare_curies!(options)
            return [] if options[:curies] == false
            LinkCollection[*compile_links_for(curie_configs, options)]
          end

          def curies_definition_options
            {
              :as       => :@namespaces,
              :extend   => Mason::Controls::LinkCollectionRepresenter,
              :instance => lambda { |*| LinkCollection.new(link_array_rels) }, # defined in InstanceMethods as this is executed in represented context.
              :exec_context => :decorator,
           }
          end
        end
      end
    end
  end
end
