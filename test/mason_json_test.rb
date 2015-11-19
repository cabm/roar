require 'test_helper'
require 'roar/json/mason'
require 'roar/json/hal'

class MasonJsonTest < MiniTest::Spec
  let(:rpr) do
    Module.new do
      include Roar::JSON
      include Roar::JSON::Mason

      link :next do
        "http://next"
      end
    end
  end

  subject { Object.new.extend(rpr) }

  describe "links" do
    describe "parsing" do
      it "parses links" do # TODO: remove me.
        obj = subject.from_json("{\"@controls\":{\"next\":{\"href\":\"http://next\"}}}")
        obj.links.must_equal "next" => link("rel" => "next", "href" => "http://next")
      end
    end

    describe "rendering" do
      it "renders links" do
        subject.to_json.must_equal "{\"@controls\":{\"next\":{\"href\":\"http://next\"}}}"
      end
    end
  end

  describe "HAL/JSON" do
    Bla = Module.new do
      include Roar::JSON::HAL
      property :title
      link :self do
        "http://songs/#{title}"
      end
    end

    representer_for([Roar::JSON::HAL]) do
      property :id
      collection :songs, :class => Song, :extend => Bla, :embedded => true
      link :self do
        "http://albums/#{id}"
      end
    end

    before do
      @album = Album.new(:songs => [Song.new(:title => "Beer")], :id => 1).extend(rpr)
    end

    it "render links and embedded resources according to HAL" do
      assert_equal "{\"id\":1,\"_embedded\":{\"songs\":[{\"title\":\"Beer\",\"_links\":{\"self\":{\"href\":\"http://songs/Beer\"}}}]},\"_links\":{\"self\":{\"href\":\"http://albums/1\"}}}", @album.to_json
    end

    it "parses links and resources following the mighty HAL" do
      @album.from_json("{\"id\":2,\"_embedded\":{\"songs\":[{\"title\":\"Coffee\",\"_links\":{\"self\":{\"href\":\"http://songs/Coffee\"}}}]},\"_links\":{\"self\":{\"href\":\"http://albums/2\"}}}")
      assert_equal 2, @album.id
      assert_equal "Coffee", @album.songs.first.title
    end

    it "doesn't require _links and _embedded to be present" do
      @album.from_json("{\"id\":2}")
      assert_equal 2, @album.id

      # in newer representables, this is not overwritten to an empty [] anymore.
      assert_equal ["Beer"], @album.songs.map(&:title)
      @album.links.must_equal nil
    end
  end

end

class JsonHalTest < MiniTest::Spec
  Album  = Struct.new(:artist, :songs)
  Artist = Struct.new(:name)
  Song = Struct.new(:title)

  def self.representer!
    super([Roar::JSON::HAL])
  end

  def representer
    rpr
  end

  describe "render_nil: false" do
    representer! do
      property :artist, embedded: true, render_nil: false do
        property :name
      end

      collection :songs, embedded: true, render_empty: false do
        property :title
      end
    end

    it { Album.new(Artist.new("Bare, Jr."), [Song.new("Tobacco Spit")]).extend(representer).to_hash.must_equal({"_embedded"=>{"artist"=>{"name"=>"Bare, Jr."}, "songs"=>[{"title"=>"Tobacco Spit"}]}}) }
    it { Album.new.extend(representer).to_hash.must_equal({}) }
  end

  describe "as: alias" do
    representer! do
      property :artist, as: :my_artist, class: Artist, embedded: true do
        property :name
      end

      collection :songs, as: :my_songs, class: Song, embedded: true do
        property :title
      end
    end

    it { Album.new(Artist.new("Bare, Jr."), [Song.new("Tobacco Spit")]).extend(representer).to_hash.must_equal({"_embedded"=>{"my_artist"=>{"name"=>"Bare, Jr."}, "my_songs"=>[{"title"=>"Tobacco Spit"}]}}) }
    it { Album.new.extend(representer).from_hash({"_embedded"=>{"my_artist"=>{"name"=>"Bare, Jr."}, "my_songs"=>[{"title"=>"Tobacco Spit"}]}}).inspect.must_equal "#<struct JsonHalTest::Album artist=#<struct JsonHalTest::Artist name=\"Bare, Jr.\">, songs=[#<struct JsonHalTest::Song title=\"Tobacco Spit\">]>" }
  end
end

class MasonCurieTest < MiniTest::Spec
  representer!([Roar::JSON::Mason]) do

    curies :zc do
        "//docs/{rel}"
    end

    link "zc:self" do
      "/"
    end
  end

  it { Object.new.extend(rpr).to_hash.must_equal(
    {
      "@namespaces"=> {
        "zc"=> {
          "name"=> "//docs/{rel}"
        }
      },
      "@controls"=> {
        "zc:self"=> {
          "href"=> "/"

        }
      }

    }
  )}
end






