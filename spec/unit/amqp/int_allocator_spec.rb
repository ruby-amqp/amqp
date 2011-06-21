# encoding: utf-8

require 'spec_helper'
require "amqp/int_allocator"

describe AMQP::IntAllocator do

  #
  # Environment
  #

  subject do
    described_class.new(1, 5)
  end


  # ...


  #
  # Examples
  #

  describe "#number_of_bits" do
    it "returns number of bits available for allocation" do
      subject.number_of_bits.should == 4
    end
  end


  describe "#hi" do
    it "returns upper bound of the allocation range" do
      subject.hi.should == 5
    end
  end

  describe "#lo" do
    it "returns lower bound of the allocation range" do
      subject.lo.should == 1
    end
  end


  describe "#allocate" do
    context "when integer in the range is available" do
      it "returns allocated integer" do
        subject.allocate.should == 1
        subject.allocate.should == 2
        subject.allocate.should == 3
        subject.allocate.should == 4

        subject.allocate.should == -1
      end
    end

    context "when integer in the range IS NOT available" do
      it "returns -1" do
        4.times { subject.allocate }

        subject.allocate.should == -1
        subject.allocate.should == -1
        subject.allocate.should == -1
        subject.allocate.should == -1
      end
    end
  end


  describe "#free" do
    context "when the integer WAS allocated" do
      it "returns frees that integer" do
        4.times { subject.allocate }
        subject.allocate.should == -1

        subject.free(1)
        subject.allocate.should == 1
        subject.allocate.should == -1
        subject.free(2)
        subject.allocate.should == 2
        subject.allocate.should == -1
        subject.free(3)
        subject.allocate.should == 3
        subject.allocate.should == -1
      end
    end

    context "when the integer WAS NOT allocated" do
      it "has no effect" do
        32.times { subject.free(1) }
        subject.allocate.should == 1
      end
    end
  end


  describe "#allocated?" do
    context "when given position WAS allocated" do
      it "returns true" do
        3.times { subject.allocate }

        subject.allocated?(1).should be_true
        subject.allocated?(2).should be_true
        subject.allocated?(3).should be_true
      end
    end

    context "when given position WAS NOT allocated" do
      it "returns false" do
        2.times { subject.allocate }

        subject.allocated?(3).should be_false
        subject.allocated?(4).should be_false
      end
    end
  end
end
