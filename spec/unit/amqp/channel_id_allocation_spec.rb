# encoding: utf-8

require "spec_helper"
describe AMQP::ChannelIdAllocator do

  class ChannelAllocator
    include AMQP::ChannelIdAllocator
  end

  describe "#next_channel_id" do
    subject do
      ChannelAllocator.new
    end

    context "when there is a channel id available for allocation" do
      it "returns that channel id" do
        1024.times { subject.next_channel_id }

        subject.next_channel_id.should == 1025
      end
    end

    context "when THERE IS NO a channel id available for allocation" do
      it "raises an exception" do
        (ChannelAllocator::MAX_CHANNELS_PER_CONNECTION - 1).times do
          subject.next_channel_id
        end

        lambda { subject.next_channel_id }.should raise_error
      end
    end
  end


  describe ".release_channel_id" do
    subject do
      ChannelAllocator.new
    end

    it "releases that channel id" do
      1024.times { subject.next_channel_id }
      subject.next_channel_id.should == 1025

      subject.release_channel_id(128)
      subject.next_channel_id.should == 128
      subject.next_channel_id.should == 1026
    end
  end

  describe "each instance gets its own channel IDs" do
    it "has an allocator per instance" do
      one = ChannelAllocator.new
      two = ChannelAllocator.new
      one.next_channel_id.should == 1
      one.next_channel_id.should == 2
      two.next_channel_id.should == 1
      two.next_channel_id.should == 2
    end
  end
end
