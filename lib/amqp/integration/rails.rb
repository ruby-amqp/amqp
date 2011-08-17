require "yaml"

module AMQP
  module Integration
    class Rails

      def self.start(options = {}, &block)
        yaml     = YAML.load_file(File.join(::Rails.root, "config", "amqp.yml"))
        settings = yaml.fetch(::Rails.env, Hash.new).symbolize_keys

        EventMachine.next_tick do
          AMQP.start(settings.merge(options), &block)
        end
      end
    end # Rails
  end # Integration
end # AMQP
