# encoding: utf-8

class MQ
  class Collection < ::Array
    class IncompatibleItemError < StandardError
      def initialize(item)
        super("Instance of #{item.class} doesn't respond to #name!")
      end
    end

    def [](name)
      self.find do |object|
        object.name == name
      end
    end

    # Collection#[]= doesn't really make any sense, as we can't
    # redefine already existing Queues and Exchanges (we can declare
    # them multiple times, but if the queue resp. exchange is already
    # in the collection, it doesn't make sense to do so and we can't
    # run declare twice in order to change options, because the AMQP
    # broker closes the connection if we try to do so).

    # Use Collection#<< for adding items to the collection.
    undef_method :[]=

    def <<(item)
      unless item.respond_to?(:name)
        raise IncompatibleItemError.new(item)
      end

      super(item) if item.name.nil? || ! self[item.name]
      return item
    end
  end
end

if $0 =~ /bacon/ or $0 == __FILE__
  require "bacon"

  Item = Struct.new(:name)

  describe MQ::Collection do
    before do
      @items = 3.times.map { |int| Item.new("name-#{int}") }
      @collection = MQ::Collection.new(@items)
    end

    describe "accessors" do
      should "be accessible by its name" do
        @collection["name-1"].should.not.be.nil
        @collection["name-1"].should.eql(@items[1])
      end

      should "not allow to change already existing object" do
        lambda { @collection["name-1"] = Item.new("test") }.should.raise(NoMethodError)
      end
    end

    describe "#<<" do
      should "raise IncompatibleItemError if the argument doesn't have method :name" do
        lambda { @collection << nil }.should.raise(MQ::Collection::IncompatibleItemError)
      end

      should "add an item into the collection" do
        length = @collection.length
        @collection << Item.new("test")
        @collection.length.should.eql(length + 1)
      end

      should "not add an item to the collection if another item with given name already exists and the name IS NOT nil" do
        @collection << Item.new("test")
        length = @collection.length
        @collection << Item.new("test")
        @collection.length.should.eql(length)
      end

      should "add an item to the collection if another item with given name already exists and the name IS nil" do
        @collection << Item.new(nil)
        length = @collection.length
        @collection << Item.new(nil)
        @collection.length.should.eql(length + 1)
      end

      should "return the item" do
        item = Item.new("test")
        (@collection << item).should.eql item
      end
    end
  end
end
