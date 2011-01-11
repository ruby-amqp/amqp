# encoding: utf-8

require File.expand_path("../../spec_helper", __FILE__)
require "mq/collection"

Item = Struct.new(:name)

describe MQ::Collection do
  before do
    @items = 3.times.map { |int| Item.new("name-#{int}") }
    @collection = MQ::Collection.new(@items)
  end

  describe "accessors" do
    it "should be accessible by its name" do
      @collection["name-1"].should_not be_nil
      @collection["name-1"].should eql(@items[1])
    end

    it "should not allow to change already existing object" do
      lambda { @collection["name-1"] = Item.new("test") }.should raise_error(NoMethodError)
    end
  end

  describe "#<<" do
    it "should raise IncompatibleItemError if the argument doesn't have method :name" do
      lambda { @collection << nil }.should raise_error(MQ::Collection::IncompatibleItemError)
    end

    it "should add an item into the collection" do
      length = @collection.length
      @collection << Item.new("test")
      @collection.length.should eql(length + 1)
    end

    it "should not add an item to the collection if another item with given name already exists and the name IS NOT nil" do
      @collection << Item.new("test")
      length = @collection.length
      @collection << Item.new("test")
      @collection.length.should eql(length)
    end

    it "should add an item to the collection if another item with given name already exists and the name IS nil" do
      @collection << Item.new(nil)
      length = @collection.length
      @collection << Item.new(nil)
      @collection.length.should eql(length + 1)
    end

    it "should return the item" do
      item = Item.new("test")
      (@collection << item).should eql item
    end

    context "when adding new item with duplicate name" do
      before do
        @original_item = Item.new("test")
        @new_item = Item.new("test")
        @collection << @original_item
      end

      it "keeps item already in collection" do
        @collection << @new_item
        @collection['test'].should eql @original_item
      end

      it "returns item already in collection" do
        (@collection << @new_item).should eql @original_item
      end
    end

    it "should return the item even if it already existed" do
      item = Item.new("test")
      @collection << item
      (@collection << item).should eql item
    end
  end

  describe "#add!" do
    it "should raise IncompatibleItemError if the argument doesn't have method :name" do
      lambda { @collection << nil }.should raise_error(MQ::Collection::IncompatibleItemError)
    end

    it "should add an item into the collection" do
      length = @collection.length
      @collection << Item.new("test")
      @collection.length.should eql(length + 1)
    end

    it "should add an item to the collection if another item with given name already exists" do
      @collection.add! Item.new("test")
      length = @collection.length
      @collection.add! Item.new("test")
      @collection.length.should eql(length + 1)
    end

    it "should return the item" do
      item = Item.new("test")
      (@collection.add! item).should eql(item)
    end
  end
end
