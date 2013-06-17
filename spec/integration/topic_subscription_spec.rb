# encoding: utf-8

require "spec_helper"
describe "Topic-based subscription" do

  #
  # Environment
  #

  include EventedSpec::AMQPSpec
  include EventedSpec::SpecHelper

  em_before { AMQP.cleanup_state }
  em_after  { AMQP.cleanup_state }

  default_options AMQP_OPTS
  default_timeout 10

  amqp_before do
    @channel   = AMQP::Channel.new
    @channel.should be_open

    @exchange = @channel.topic
  end

  after(:all) do
    AMQP.cleanup_state
    done
  end


  #
  # Examples
  #

  context "when keys match exactly" do
    it "routes messages to bound queues" do
      @aapl_queue = @channel.queue("AAPL queue", :auto_delete => true)
      @amzn_queue = @channel.queue("AMZN queue", :auto_delete => true)

      received_messages = {
        @aapl_queue.name => 0,
        @amzn_queue.name => 0
      }

      expected_messages = {
        @aapl_queue.name => 4,
        @amzn_queue.name => 2
      }

      @aapl_queue.bind(@exchange, :key => "nasdaq.aapl").subscribe do |payload|
        received_messages[@aapl_queue.name] += 1
      end
      @amzn_queue.bind(@exchange, :key => "nasdaq.amzn").subscribe do |payload|
        received_messages[@amzn_queue.name] += 1
      end

      4.times do
        @exchange.publish(332 + rand(1000)/400.0, :key => "nasdaq.aapl")
      end

      2.times do
        @exchange.publish(181 + rand(1000)/400.0, :key => "nasdaq.amzn")
      end

      # publish some messages none of our queues should be receiving
      3.times do
        @exchange.publish(626 + rand(1000)/400.0, :key => "nasdaq.goog")
      end

      done(0.5) {
        received_messages.should == expected_messages
        @aapl_queue.unsubscribe
        @amzn_queue.unsubscribe
      }
    end # it
  end # context


  context "when key matches on * (single word globbing)" do
    it "routes messages to bound queues" do
      @nba_queue     = @channel.queue("NBA queue", :auto_delete => true)
      @knicks_queue  = @channel.queue("New York Knicks queue", :auto_delete => true)
      @celtics_queue = @channel.queue("Boston Celtics queue", :auto_delete => true)

      received_messages = {
        @nba_queue.name     => 0,
        @knicks_queue.name  => 0,
        @celtics_queue.name => 0
      }

      expected_messages = {
        @nba_queue.name     => 7,
        @knicks_queue.name  => 2,
        @celtics_queue.name => 3
      }

      @nba_queue.bind(@exchange, :key => "sports.nba.*").subscribe do |payload|
        received_messages[@nba_queue.name] += 1
      end

      @knicks_queue.bind(@exchange, :key => "sports.nba.knicks").subscribe do |payload|
        received_messages[@knicks_queue.name] += 1
      end

      @celtics_queue.bind(@exchange, :key => "sports.nba.celtics").subscribe do |payload|
        received_messages[@celtics_queue.name] += 1
      end

      @exchange.publish("Houston Rockets 104 : New York Knicks 89", :key => "sports.nba.knicks")
      @exchange.publish("Phoenix Suns 129 : New York Knicks 121", :key => "sports.nba.knicks")

      @exchange.publish("Ray Allen hit a 21-foot jumper with 24.5 seconds remaining on the clock to give Boston a win over Detroit last night in the TD Garden", :key => "sports.nba.celtics")
      @exchange.publish("Garnett's Return Sparks Celtics Over Magic at Garden", :key => "sports.nba.celtics")
      @exchange.publish("Tricks of the Trade: Allen Reveals Magic of Big Shots", :key => "sports.nba.celtics")

      @exchange.publish("Blatche, Wall lead Wizards over Jazz 108-101", :key => "sports.nba.jazz")
      @exchange.publish("Deron Williams Receives NBA Cares Community Assist Award", :key => "sports.nba.jazz")

      done(0.6) {
        received_messages.should == expected_messages

        @nba_queue.unsubscribe
        @knicks_queue.unsubscribe
        @celtics_queue.unsubscribe
      }
    end # it
  end # context




  context "when key matches on # (multiple words globbing)" do
    it "routes messages to bound queues" do
      @sports_queue  = @channel.queue("Sports queue", :auto_delete => true)
      @nba_queue     = @channel.queue("NBA queue", :auto_delete => true)
      @knicks_queue  = @channel.queue("New York Knicks queue", :auto_delete => true)
      @celtics_queue = @channel.queue("Boston Celtics queue", :auto_delete => true)

      received_messages = {
        @sports_queue.name  => 0,
        @nba_queue.name     => 0,
        @knicks_queue.name  => 0,
        @celtics_queue.name => 0
      }

      expected_messages = {
        @sports_queue.name  => 9,
        @nba_queue.name     => 7,
        @knicks_queue.name  => 2,
        @celtics_queue.name => 3
      }


      @sports_queue.bind(@exchange, :key => "sports.#").subscribe do |payload|
        received_messages[@sports_queue.name] += 1
      end

      @nba_queue.bind(@exchange, :key => "*.nba.*").subscribe do |payload|
        received_messages[@nba_queue.name] += 1
      end

      @knicks_queue.bind(@exchange, :key => "sports.nba.knicks").subscribe do |payload|
        received_messages[@knicks_queue.name] += 1
      end

      @celtics_queue.bind(@exchange, :key => "#.celtics").subscribe do |payload|
        received_messages[@celtics_queue.name] += 1
      end

      @exchange.publish("Houston Rockets 104 : New York Knicks 89", :key => "sports.nba.knicks")
      @exchange.publish("Phoenix Suns 129 : New York Knicks 121", :key => "sports.nba.knicks")

      @exchange.publish("Ray Allen hit a 21-foot jumper with 24.5 seconds remaining on the clock to give Boston a win over Detroit last night in the TD Garden", :key => "sports.nba.celtics")
      @exchange.publish("Garnett's Return Sparks Celtics Over Magic at Garden", :key => "sports.nba.celtics")
      @exchange.publish("Tricks of the Trade: Allen Reveals Magic of Big Shots", :key => "sports.nba.celtics")

      @exchange.publish("Blatche, Wall lead Wizards over Jazz 108-101", :key => "sports.nba.jazz")
      @exchange.publish("Deron Williams Receives NBA Cares Community Assist Award", :key => "sports.nba.jazz")

      @exchange.publish("Philadelphia's Daniel Briere has been named as an All-Star replacement for Jarome Iginla.", :key => "sports.nhl.allstargame")
      @exchange.publish("Devils blank Sid- and Malkin-less Penguins 2-0", :key => "sports.nhl.penguins")

      done(0.5) {
        received_messages.should == expected_messages

        @sports_queue.unsubscribe
        @nba_queue.unsubscribe
        @knicks_queue.unsubscribe
        @celtics_queue.unsubscribe
      }
    end # it
  end # context
end # describe
