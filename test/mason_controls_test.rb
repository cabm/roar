require 'ostruct'
require 'test_helper'
require 'roar/json/mason'
require 'roar/json/hal'


class MasonControlsTest < MiniTest::Spec
  let(:rpr) do
    Module.new do
      include Roar::JSON
      include Roar::JSON::HAL::Links::LinkCollectionRepresenter
      include Roar::JSON::Mason::Controls
      link :self do
        "//songs"
      end
    end
  end

  subject { Object.new.extend(rpr) }

  describe "#to_json" do
    it "uses '@controls' key" do
      subject.to_json.must_equal "{\"@controls\":{\"self\":{\"href\":\"//songs\"}}}"
    end
  end

  describe "#from_json" do
    it "uses '@controls' key" do
      subject.from_json("{\"@controls\":{\"self\":{\"href\":\"//lifer\"}}}").links.values.must_equal [link("href" => "//lifer", "rel" => "self")]
    end
  end
end

