# encoding: utf-8

module AMQP
  # AMQP::Collection is used to store named AMQ model entities (exchanges, queues)
  class Collection < ::Array
    class IncompatibleItemError < ArgumentError
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

    # Use Collection# << for adding items to the collection.
    undef_method :[]=

    def <<(item)
      if (item.name rescue nil).nil? || !self[item.name]
        self.add!(item)
      end

      # We can't just return the item, because in case the item isn't added
      # to the collection, then it'd be different from self[item.name].
      return self[item.name]
    end

    alias_method :__push__, :push
    alias_method :push, :<<

    def add!(item)
      unless item.respond_to?(:name)
        raise IncompatibleItemError.new(item)
      end

      __push__(item)
      return item
    end

    def delete(name)
      self.delete_at(self.index(self[name]))
    end
  end
end
