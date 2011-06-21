require "spec_helper"

describe AMQP::Channel do
  describe ".next_channel_id" do
    before :all do
      described_class.reset_channel_id_allocator
    end

    context "when there is a channel id available for allocation" do
      it "returns that channel id" do
        1024.times { described_class.next_channel_id }

        described_class.next_channel_id.should == 1025
      end
    end

    context "when THERE IS NOT channel id available for allocation" do
      it "raises an exception"
    end
  end



  describe ".release_channel_id" do
    before :all do
      described_class.reset_channel_id_allocator
    end

    it "releases that channel id" do
      1024.times { described_class.next_channel_id }
      described_class.next_channel_id.should == 1025

      described_class.release_channel_id(128)
      described_class.next_channel_id.should == 128
      described_class.next_channel_id.should == 1026
    end
  end
end
