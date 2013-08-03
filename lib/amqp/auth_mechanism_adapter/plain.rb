# encoding: utf-8

module AMQP

  # Manages the encoding of credentials for the PLAIN authentication
  # mechanism.
  class AuthMechanismAdapter::Plain < AuthMechanismAdapter

    auth_mechanism "PLAIN"

    # Encodes credentials for the given username and password. This
    # involves sending the password across the wire in plaintext, so
    # PLAIN authentication should only be used over a secure transport
    # layer.
    #
    # @param [String] username The username to encode.
    # @param [String] password The password to encode.
    # @return [String] The username and password, encoded for the PLAIN
    #   mechanism.
    def encode_credentials(username, password)
      "\0#{username}\0#{password}"
    end
  end
end
