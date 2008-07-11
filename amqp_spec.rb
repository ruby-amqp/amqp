
module AMQP
  VERSION_MAJOR = 8
  VERSION_MINOR = 0
  DEFAULT_PORT  = 5672

  FRAME_METHOD        = 1
  FRAME_HEADER        = 2
  FRAME_BODY          = 3
  FRAME_OOB_METHOD    = 4
  FRAME_OOB_HEADER    = 5
  FRAME_OOB_BODY      = 6
  FRAME_TRACE         = 7
  FRAME_HEARTBEAT     = 8
  FRAME_MIN_SIZE      = 4096
  FRAME_END           = 206
  REPLY_SUCCESS       = 200
  NOT_DELIVERED       = 310
  CONTENT_TOO_LARGE   = 311
  NO_ROUTE            = 312
  NO_CONSUMERS        = 313
  ACCESS_REFUSED      = 403
  NOT_FOUND           = 404
  RESOURCE_LOCKED     = 405
  PRECONDITION_FAILED = 406
  CONNECTION_FORCED   = 320
  INVALID_PATH        = 402
  FRAME_ERROR         = 501
  SYNTAX_ERROR        = 502
  COMMAND_INVALID     = 503
  CHANNEL_ERROR       = 504
  RESOURCE_ERROR      = 506
  NOT_ALLOWED         = 530
  NOT_IMPLEMENTED     = 540
  INTERNAL_ERROR      = 541

  DOMAINS = {
    :"access-ticket" => :short,
    :"channel-id" => :longstr,
    :"class-id" => :short,
    :"consumer-tag" => :shortstr,
    :"delivery-tag" => :longlong,
    :"destination" => :shortstr,
    :"duration" => :longlong,
    :"exchange-name" => :shortstr,
    :"known-hosts" => :shortstr,
    :"method-id" => :short,
    :"no-ack" => :bit,
    :"no-local" => :bit,
    :"offset" => :longlong,
    :"path" => :shortstr,
    :"peer-properties" => :table,
    :"queue-name" => :shortstr,
    :"redelivered" => :bit,
    :"reference" => :longstr,
    :"reject-code" => :short,
    :"reject-text" => :shortstr,
    :"reply-code" => :short,
    :"reply-text" => :shortstr,
    :"security-token" => :longstr,
  }

  FIELDS = [
    :bit,
    :long,
    :longlong,
    :longstr,
    :octet,
    :short,
    :shortstr,
    :table,
    :timestamp,
  ]

  module Protocol
    class Class
      class << self
        FIELDS.each do |f|
          class_eval %[
            def #{f} name
              properties << [ :#{f}, name ] unless properties.include?([:#{f}, name])
              attr_accessor name
            end
          ]
        end
        
        def properties() @properties ||= [] end

        def id()   self::ID end
        def name() self::NAME end
      end

      class Method
        class << self
          FIELDS.each do |f|
            class_eval %[
              def #{f} name
                arguments << [ :#{f}, name ] unless arguments.include?([:#{f}, name])
                attr_accessor name
              end
            ]
          end
          
          def arguments() @arguments ||= [] end

          def parent() Protocol.const_get(self.to_s[/Protocol::(.+?)::/,1]) end
          def id()     self::ID end
          def name()   self::NAME end
        end

        def == b
          self.class.arguments.inject(true) do |eql, (type, name)|
            eql and __send__("#{name}") == b.__send__("#{name}")
          end
        end
      end
    
      def self.methods() @methods ||= {} end
    
      def self.Method(id, name)
        @_base_methods ||= {}
        @_base_methods[id] ||= ::Class.new(Method) do
          class_eval %[
            def self.inherited klass
              klass.const_set(:ID, #{id})
              klass.const_set(:NAME, :#{name.to_s.dump})
              klass.parent.methods[#{id}] = klass
            end
          ]
        end
      end
    end

    def self.classes() @classes ||= {} end

    def self.Class(id, name)
      @_base_classes ||= {}
      @_base_classes[id] ||= ::Class.new(Class) do
        class_eval %[
          def self.inherited klass
            klass.const_set(:ID, #{id})
            klass.const_set(:NAME, :#{name.to_s.dump})
            Protocol.classes[#{id}] = klass
          end
        ]
      end
    end
    
    class Connection < Class(10, :connection)

      class Start < Method(10, :'start')
        octet      :version_major
        octet      :version_minor
        table      :server_properties
        longstr    :mechanisms
        longstr    :locales
      end

      class StartOk < Method(11, :'start-ok')
        table      :client_properties
        shortstr   :mechanism
        longstr    :response
        shortstr   :locale
      end

      class Secure < Method(20, :'secure')
        longstr    :challenge
      end

      class SecureOk < Method(21, :'secure-ok')
        longstr    :response
      end

      class Tune < Method(30, :'tune')
        short      :channel_max
        long       :frame_max
        short      :heartbeat
      end

      class TuneOk < Method(31, :'tune-ok')
        short      :channel_max
        long       :frame_max
        short      :heartbeat
      end

      class Open < Method(40, :'open')
        shortstr   :virtual_host
        shortstr   :capabilities
        bit        :insist
      end

      class OpenOk < Method(41, :'open-ok')
        shortstr   :known_hosts
      end

      class Redirect < Method(50, :'redirect')
        shortstr   :host
        shortstr   :known_hosts
      end

      class Close < Method(60, :'close')
        short      :reply_code
        shortstr   :reply_text
        short      :class_id
        short      :method_id
      end

      class CloseOk < Method(61, :'close-ok')
      end

    end

    class Channel < Class(20, :channel)

      class Open < Method(10, :'open')
        shortstr   :out_of_band
      end

      class OpenOk < Method(11, :'open-ok')
      end

      class Flow < Method(20, :'flow')
        bit        :active
      end

      class FlowOk < Method(21, :'flow-ok')
        bit        :active
      end

      class Alert < Method(30, :'alert')
        short      :reply_code
        shortstr   :reply_text
        table      :details
      end

      class Close < Method(40, :'close')
        short      :reply_code
        shortstr   :reply_text
        short      :class_id
        short      :method_id
      end

      class CloseOk < Method(41, :'close-ok')
      end

    end

    class Access < Class(30, :access)

      class Request < Method(10, :'request')
        shortstr   :realm
        bit        :exclusive
        bit        :passive
        bit        :active
        bit        :write
        bit        :read
      end

      class RequestOk < Method(11, :'request-ok')
        short      :ticket
      end

    end

    class Exchange < Class(40, :exchange)

      class Declare < Method(10, :'declare')
        short      :ticket
        shortstr   :exchange
        shortstr   :type
        bit        :passive
        bit        :durable
        bit        :auto_delete
        bit        :internal
        bit        :nowait
        table      :arguments
      end

      class DeclareOk < Method(11, :'declare-ok')
      end

      class Delete < Method(20, :'delete')
        short      :ticket
        shortstr   :exchange
        bit        :if_unused
        bit        :nowait
      end

      class DeleteOk < Method(21, :'delete-ok')
      end

    end

    class Queue < Class(50, :queue)

      class Declare < Method(10, :'declare')
        short      :ticket
        shortstr   :queue
        bit        :passive
        bit        :durable
        bit        :exclusive
        bit        :auto_delete
        bit        :nowait
        table      :arguments
      end

      class DeclareOk < Method(11, :'declare-ok')
        shortstr   :queue
        long       :message_count
        long       :consumer_count
      end

      class Bind < Method(20, :'bind')
        short      :ticket
        shortstr   :queue
        shortstr   :exchange
        shortstr   :routing_key
        bit        :nowait
        table      :arguments
      end

      class BindOk < Method(21, :'bind-ok')
      end

      class Purge < Method(30, :'purge')
        short      :ticket
        shortstr   :queue
        bit        :nowait
      end

      class PurgeOk < Method(31, :'purge-ok')
        long       :message_count
      end

      class Delete < Method(40, :'delete')
        short      :ticket
        shortstr   :queue
        bit        :if_unused
        bit        :if_empty
        bit        :nowait
      end

      class DeleteOk < Method(41, :'delete-ok')
        long       :message_count
      end

    end

    class Basic < Class(60, :basic)
      shortstr   :content_type
      shortstr   :content_encoding
      table      :headers
      octet      :delivery_mode
      octet      :priority
      shortstr   :correlation_id
      shortstr   :reply_to
      shortstr   :expiration
      shortstr   :message_id
      timestamp  :timestamp
      shortstr   :type
      shortstr   :user_id
      shortstr   :app_id
      shortstr   :cluster_id

      class Qos < Method(10, :'qos')
        long       :prefetch_size
        short      :prefetch_count
        bit        :global
      end

      class QosOk < Method(11, :'qos-ok')
      end

      class Consume < Method(20, :'consume')
        short      :ticket
        shortstr   :queue
        shortstr   :consumer_tag
        bit        :no_local
        bit        :no_ack
        bit        :exclusive
        bit        :nowait
      end

      class ConsumeOk < Method(21, :'consume-ok')
        shortstr   :consumer_tag
      end

      class Cancel < Method(30, :'cancel')
        shortstr   :consumer_tag
        bit        :nowait
      end

      class CancelOk < Method(31, :'cancel-ok')
        shortstr   :consumer_tag
      end

      class Publish < Method(40, :'publish')
        short      :ticket
        shortstr   :exchange
        shortstr   :routing_key
        bit        :mandatory
        bit        :immediate
      end

      class Return < Method(50, :'return')
        short      :reply_code
        shortstr   :reply_text
        shortstr   :exchange
        shortstr   :routing_key
      end

      class Deliver < Method(60, :'deliver')
        shortstr   :consumer_tag
        longlong   :delivery_tag
        bit        :redelivered
        shortstr   :exchange
        shortstr   :routing_key
      end

      class Get < Method(70, :'get')
        short      :ticket
        shortstr   :queue
        bit        :no_ack
      end

      class GetOk < Method(71, :'get-ok')
        longlong   :delivery_tag
        bit        :redelivered
        shortstr   :exchange
        shortstr   :routing_key
        long       :message_count
      end

      class GetEmpty < Method(72, :'get-empty')
        shortstr   :cluster_id
      end

      class Ack < Method(80, :'ack')
        longlong   :delivery_tag
        bit        :multiple
      end

      class Reject < Method(90, :'reject')
        longlong   :delivery_tag
        bit        :requeue
      end

      class Recover < Method(100, :'recover')
        bit        :requeue
      end

    end

    class File < Class(70, :file)
      shortstr   :content_type
      shortstr   :content_encoding
      table      :headers
      octet      :priority
      shortstr   :reply_to
      shortstr   :message_id
      shortstr   :filename
      timestamp  :timestamp
      shortstr   :cluster_id

      class Qos < Method(10, :'qos')
        long       :prefetch_size
        short      :prefetch_count
        bit        :global
      end

      class QosOk < Method(11, :'qos-ok')
      end

      class Consume < Method(20, :'consume')
        short      :ticket
        shortstr   :queue
        shortstr   :consumer_tag
        bit        :no_local
        bit        :no_ack
        bit        :exclusive
        bit        :nowait
      end

      class ConsumeOk < Method(21, :'consume-ok')
        shortstr   :consumer_tag
      end

      class Cancel < Method(30, :'cancel')
        shortstr   :consumer_tag
        bit        :nowait
      end

      class CancelOk < Method(31, :'cancel-ok')
        shortstr   :consumer_tag
      end

      class Open < Method(40, :'open')
        shortstr   :identifier
        longlong   :content_size
      end

      class OpenOk < Method(41, :'open-ok')
        longlong   :staged_size
      end

      class Stage < Method(50, :'stage')
      end

      class Publish < Method(60, :'publish')
        short      :ticket
        shortstr   :exchange
        shortstr   :routing_key
        bit        :mandatory
        bit        :immediate
        shortstr   :identifier
      end

      class Return < Method(70, :'return')
        short      :reply_code
        shortstr   :reply_text
        shortstr   :exchange
        shortstr   :routing_key
      end

      class Deliver < Method(80, :'deliver')
        shortstr   :consumer_tag
        longlong   :delivery_tag
        bit        :redelivered
        shortstr   :exchange
        shortstr   :routing_key
        shortstr   :identifier
      end

      class Ack < Method(90, :'ack')
        longlong   :delivery_tag
        bit        :multiple
      end

      class Reject < Method(100, :'reject')
        longlong   :delivery_tag
        bit        :requeue
      end

    end

    class Stream < Class(80, :stream)
      shortstr   :content_type
      shortstr   :content_encoding
      table      :headers
      octet      :priority
      timestamp  :timestamp

      class Qos < Method(10, :'qos')
        long       :prefetch_size
        short      :prefetch_count
        long       :consume_rate
        bit        :global
      end

      class QosOk < Method(11, :'qos-ok')
      end

      class Consume < Method(20, :'consume')
        short      :ticket
        shortstr   :queue
        shortstr   :consumer_tag
        bit        :no_local
        bit        :exclusive
        bit        :nowait
      end

      class ConsumeOk < Method(21, :'consume-ok')
        shortstr   :consumer_tag
      end

      class Cancel < Method(30, :'cancel')
        shortstr   :consumer_tag
        bit        :nowait
      end

      class CancelOk < Method(31, :'cancel-ok')
        shortstr   :consumer_tag
      end

      class Publish < Method(40, :'publish')
        short      :ticket
        shortstr   :exchange
        shortstr   :routing_key
        bit        :mandatory
        bit        :immediate
      end

      class Return < Method(50, :'return')
        short      :reply_code
        shortstr   :reply_text
        shortstr   :exchange
        shortstr   :routing_key
      end

      class Deliver < Method(60, :'deliver')
        shortstr   :consumer_tag
        longlong   :delivery_tag
        shortstr   :exchange
        shortstr   :queue
      end

    end

    class Tx < Class(90, :tx)

      class Select < Method(10, :'select')
      end

      class SelectOk < Method(11, :'select-ok')
      end

      class Commit < Method(20, :'commit')
      end

      class CommitOk < Method(21, :'commit-ok')
      end

      class Rollback < Method(30, :'rollback')
      end

      class RollbackOk < Method(31, :'rollback-ok')
      end

    end

    class Dtx < Class(100, :dtx)

      class Select < Method(10, :'select')
      end

      class SelectOk < Method(11, :'select-ok')
      end

      class Start < Method(20, :'start')
        shortstr   :dtx_identifier
      end

      class StartOk < Method(21, :'start-ok')
      end

    end

    class Tunnel < Class(110, :tunnel)
      table      :headers
      shortstr   :proxy_name
      shortstr   :data_name
      octet      :durable
      octet      :broadcast

      class Request < Method(10, :'request')
        table      :meta_data
      end

    end

    class Test < Class(120, :test)

      class Integer < Method(10, :'integer')
        octet      :integer_1
        short      :integer_2
        long       :integer_3
        longlong   :integer_4
        octet      :operation
      end

      class IntegerOk < Method(11, :'integer-ok')
        longlong   :result
      end

      class String < Method(20, :'string')
        shortstr   :string_1
        longstr    :string_2
        octet      :operation
      end

      class StringOk < Method(21, :'string-ok')
        longstr    :result
      end

      class Table < Method(30, :'table')
        table      :table
        octet      :integer_op
        octet      :string_op
      end

      class TableOk < Method(31, :'table-ok')
        longlong   :integer_result
        longstr    :string_result
      end

      class Content < Method(40, :'content')
      end

      class ContentOk < Method(41, :'content-ok')
        long       :content_checksum
      end

    end

  end
end
