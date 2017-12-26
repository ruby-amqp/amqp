# encoding: utf-8

module AMQP
  module Settings
    CLIENT_PROPERTIES = {
      :platform    => ::RUBY_DESCRIPTION,
      :product     => "amqp gem",
      :information => "http://github.com/ruby-amqp/amqp",
      :version     => AMQP::VERSION,
      :capabilities => {
        :publisher_confirms           => true,
        :consumer_cancel_notify       => true,
        :exchange_exchange_bindings   => true,
        :"basic.nack"                 => true,
        :"connection.blocked"         => true,
        :authentication_failure_close => true
      }
    }

    def self.client_properties
      @client_properties ||= CLIENT_PROPERTIES
    end
  end
end
