require 'test_helper'
require 'roar/json/mason'
require 'roar/json/hal'
require 'pry'

class MasonJsonTest < MiniTest::Spec
  let(:rpr) do
    Module.new do
      include Roar::JSON
      include Roar::JSON::Mason

      link :self do
        {
          href: "http://post",
          method: "POST"
        }
      end

      link :next do
        "http://next"
      end
    end
  end

  subject { Object.new.extend(rpr) }

  describe "link" do
    describe "rendering" do
      it "renders link and link with params" do
        subject.to_json.must_equal "{\"@controls\":{\"self\":{\"href\":\"http://post\",\"method\":\"POST\"},\"next\":{\"href\":\"http://next\"}}}"
      end
    end
  end


  describe "@controls" do
    representer_for([Roar::JSON::Mason]) do
      property :id
      collection :songs, class: Song, embedded: true do
        include Roar::JSON::Mason

        property :title
        link(:self) { "http://songs/#{title}" }
      end

      link(:self) { "http://albums/#{id}" }
    end

    let(:album) { Album.new(:songs => [Song.new(:title => "Beer")], :id => 1).extend(representer) }

    it "render controls and embedded resources according to Mason" do
      album.to_json.must_equal "{\"id\":1,\"songs\":[{\"title\":\"Beer\",\"@controls\":{\"self\":{\"href\":\"http://songs/Beer\"}}}],\"@controls\":{\"self\":{\"href\":\"http://albums/1\"}}}"
    end
  end
end

# class JsonHalTest < MiniTest::Spec
#   Album  = Struct.new(:artist, :songs)
#   Artist = Struct.new(:name)
#   Song = Struct.new(:title)

#   def self.representer!
#     super([Roar::JSON::HAL])
#   end

#   def representer
#     rpr
#   end

#   describe "render_nil: false" do
#     representer! do
#       property :artist, embedded: true, render_nil: false do
#         property :name
#       end

#       collection :songs, embedded: true, render_empty: false do
#         property :title
#       end
#     end

#     it { Album.new(Artist.new("Bare, Jr."), [Song.new("Tobacco Spit")]).extend(representer).to_hash.must_equal({"_embedded"=>{"artist"=>{"name"=>"Bare, Jr."}, "songs"=>[{"title"=>"Tobacco Spit"}]}}) }
#     it { Album.new.extend(representer).to_hash.must_equal({}) }
#   end

#   describe "as: alias" do
#     representer! do
#       property :artist, as: :my_artist, class: Artist, embedded: true do
#         property :name
#       end

#       collection :songs, as: :my_songs, class: Song, embedded: true do
#         property :title
#       end
#     end

#     it { Album.new(Artist.new("Bare, Jr."), [Song.new("Tobacco Spit")]).extend(representer).to_hash.must_equal({"_embedded"=>{"my_artist"=>{"name"=>"Bare, Jr."}, "my_songs"=>[{"title"=>"Tobacco Spit"}]}}) }
#     it { Album.new.extend(representer).from_hash({"_embedded"=>{"my_artist"=>{"name"=>"Bare, Jr."}, "my_songs"=>[{"title"=>"Tobacco Spit"}]}}).inspect.must_equal "#<struct JsonHalTest::Album artist=#<struct JsonHalTest::Artist name=\"Bare, Jr.\">, songs=[#<struct JsonHalTest::Song title=\"Tobacco Spit\">]>" }
#   end
# end

class MasonCurieTest < MiniTest::Spec
  representer!([Roar::JSON::Mason]) do
    link "doc:self" do
      "/"
    end

    curies :doc do
      "//docs/{rel}"
    end
  end

  it {  Object.new.extend(rpr).to_hash.must_equal({"@controls"=>{"doc:self"=>{"href"=>"/"}}, "@namespaces"=>{"doc" => { "name" => "//docs/{rel}"}}}) }
end
