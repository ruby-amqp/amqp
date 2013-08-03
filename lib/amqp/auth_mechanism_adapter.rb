# encoding: utf-8

module AMQP
  # Provides a flexible method for encoding AMQP credentials. PLAIN and
  # EXTERNAL are provided by this gem. In order to implement a new
  # authentication mechanism, create a subclass like so:
  #
  #   class MyAuthMechanism < AMQP::Async::AuthMechanismAdapter
  #     auth_mechanism "X-MYAUTH"
  #
  #     def encode_credentials(username, password)
  #       # ...
  #     end
  #   end
  class AuthMechanismAdapter

    # Find and instantiate an AuthMechanismAdapter.
    #
    # @param [Adapter] adapter The Adapter for which to encode credentials.
    # @return [AuthMechanismAdapter] An AuthMechanismAdapter that can encode
    #   credentials for the Adapter.
    # @raise [NotImplementedError] The Adapter's mechanism does not
    #   correspond to any known AuthMechanismAdapter.
    def self.for_adapter(adapter)
      registry[adapter.mechanism].new adapter
    end

    protected

      # Used by subclasses to declare the mechanisms that an
      # AuthMechanismAdapter understands.
      #
      # @param [Array<String>] mechanisms One or more mechanisms that can be
      #   handled by the subclass.
      def self.auth_mechanism(*mechanisms)
        mechanisms.each {|mechanism| registry[mechanism] = self}
      end

    private

      # Accesses the registry of AuthMechanismAdapter subclasses. Keys in
      # this hash are the names of the authentication mechanisms; values are
      # the classes that handle them. Referencing an unknown mechanism from
      # this Hash will raise NotImplementedError.
      def self.registry
        @@registry ||= Hash.new {raise NotImplementedError}
      end

    public

      # The Adapter that this AuthMechanismAdapter operates on behalf of.
      attr_reader :adapter

    private

      # Create a new AuthMechanismAdapter. Users of this class should instead
      # retrieve an instance through for_adapter.
      def initialize(adapter)
        @adapter = adapter
      end
  end
end

# pre-require builtin auth mechanisms
Dir[File.join(File.dirname(__FILE__),
              File.basename(__FILE__, '.rb'),
              '*')].each do |f|
  require f
end
