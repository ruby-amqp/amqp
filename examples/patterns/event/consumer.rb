# encoding: utf-8

$LOAD_PATH.unshift File.expand_path("../../../../lib", __FILE__)

require "amqp"
require "yaml"

t = Thread.new { EventMachine.run }
sleep(0.5)


connection = AMQP.connect
channel    = AMQP::Channel.new(connection, :auto_recovery => true)
channel.on_error do |ch, channel_close|
  raise "Channel-level exception: #{channel_close.reply_text}"
end

channel.prefetch(1)

channel.queue("", :durable => false, :auto_delete => true).bind("amqpgem.patterns.events").subscribe do |metadata, payload|
  begin
    body = YAML.load(payload)

    case metadata.type
    when "widgets.created"   then
      puts "A widget #{body[:id]} was created"
    when "widgets.destroyed" then
      puts "A widget #{body[:id]} was destroyed"
    when "files.created"     then
      puts "A new file (#{body[:filename]}, #{body[:sha1]}) was uploaded"
    when "files.indexed"     then
      puts "A new file (#{body[:filename]}, #{body[:sha1]}) was indexed"
    else
      puts "[warn] Do not know how to handle event of type #{metadata.type}"
    end
  rescue Exception => e
    puts "[error] Could not handle event of type #{metadata.type}: #{e.inspect}"
  end
end

puts "[boot] Ready"
Signal.trap("INT") { connection.close { EventMachine.stop } }
t.join
