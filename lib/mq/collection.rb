# encoding: utf-8

class MQ
  class Collection < ::Array
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

    should "be accessible by its name" do
      @collection["name-1"].should.not.be.nil
      @collection["name-1"].should.eql(@items[1])
    end

    should "not allow to change already existing object" do
      lambda { @collection["name-1"] = Item.new("test") }.should.raise(NoMethodError)
    end
  end
end
