# encoding: utf-8

require "spec_helper"
require "mq/collection"

Item = Struct.new(:name)

describe MQ::Collection do
  before do
    @items = 3.times.map { |int| Item.new("name-#{int}") }
    @collection = MQ::Collection.new(@items)
  end

  it "provides access to items by name" do
    @collection["name-1"].should_not be_nil
    @collection["name-1"].should eql(@items[1])
  end

  it "DOES NOT allow modification of existing items" do
    lambda { @collection["name-1"] = Item.new("test") }.should raise_error(NoMethodError)
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

    context "when another item with given name already exists and the name IS NOT nil" do
      it "should not add an item to the collection" do
        @collection << Item.new("test")
        length = @collection.length
        @collection << Item.new("test")
        @collection.length.should eql(length)
      end # it
    end # context


    context "when another item with given name already exists and the name IS nil" do
      it "should add an item to the collection" do
        @collection << Item.new(nil)
        length = @collection.length
        @collection << Item.new(nil)
        @collection.length.should eql(length + 1)
      end # it
    end # context

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

    context "when item we add already exists in the collection" do
      it "should return the item" do
        item = Item.new("test")
        @collection << item
        (@collection << item).should eql item
      end # it
    end # context
  end # describe




  describe "#add!" do
    context "when the argument doesn't respond to :name" do
      it "should raise IncompatibleItemError " do
        lambda { @collection.add!(nil) }.should raise_error(MQ::Collection::IncompatibleItemError)
      end # it
    end

    context "when another item with given name already exists" do
      it "should add an item to the collection" do
        @collection.add! Item.new("test")
        lambda do
          @collection.add!(Item.new("test"))
        end.should change(@collection, :length).by(1)
      end # it
    end # context

    it "should return the item" do
      item = Item.new("test")
      (@collection.add! item).should eql(item)
    end # it
  end # describe





  describe "#<<" do
    context "when the argument doesn't respond to :name" do
      it "should raise IncompatibleItemError " do
        lambda { @collection << nil }.should raise_error(MQ::Collection::IncompatibleItemError)
      end # it
    end # context

    context "when the argument DOES respond to :name" do
      it "should add an item into the collection" do
        lambda do
          @collection << Item.new("test")
        end.should change(@collection, :length).by(1)
      end
    end # context
  end # describe
end # describe MQ::Collection
