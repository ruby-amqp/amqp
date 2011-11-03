require "yaml"

module AMQP
  module Integration
    class Rails

      def self.start(options_or_uri = {}, &block)
        yaml     = YAML.load_file(File.join(::Rails.root, "config", "amqp.yml"))
        settings = yaml.fetch(::Rails.env, Hash.new).symbolize_keys

        arg      = if options_or_uri.is_a?(Hash)
                     settings.merge(options_or_uri)[:uri]
                   else
                     settings[:uri] || options_or_uri
                   end

        EventMachine.next_tick do
          AMQP.start(arg, &block)
        end
      end
    end # Rails
  end # Integration
end # AMQP
