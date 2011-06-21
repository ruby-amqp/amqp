# encoding: utf-8

require 'spec_helper'

require "amqp/bit_set"


describe AMQP::BitSet do

  #
  # Environment
  #

  let(:nbits) { (1 << 16) - 1 }


  #
  # Examples
  #

  describe "#get, #[]" do
    describe "when bit at given position is set" do
      subject do
        o = described_class.new(nbits)
        o.set(3)
        o
      end

      it "returns true" do
        subject.get(3).should be_true
      end # it
    end # describe

    describe "when bit at given position is off" do
      subject do
        described_class.new(nbits)
      end

      it "returns false" do
        subject.get(5).should be_false
      end # it
    end # describe
  end # describe


  describe "#set" do
    describe "when bit at given position is set" do
      subject do
        described_class.new(nbits)
      end

      it "has no effect" do
        subject.set(3)
        subject.get(3).should be_true
        subject.set(3)
        subject[3].should be_true
      end # it
    end

    describe "when bit at given position is off" do
      subject do
        described_class.new(nbits)
      end

      it "sets that bit" do
        subject.set(3)
        subject.get(3).should be_true

        subject.set(33)
        subject.get(33).should be_true

        subject.set(3387)
        subject.get(3387).should be_true
      end
    end # describe
  end # describe


  describe "#unset" do
    describe "when bit at a given position is set" do
      subject do
        described_class.new(nbits)
      end

      it "unsets that bit" do
        subject.set(3)
        subject.get(3).should be_true
        subject.unset(3)
        subject.get(3).should be_false
      end # it
    end # describe


    describe "when bit at a given position is off" do
      subject do
        described_class.new(nbits)
      end

      it "has no effect" do
        subject.get(3).should be_false
        subject.unset(3)
        subject.get(3).should be_false
      end # it
    end # describe
  end # describe



  describe "#clear" do
    subject do
      described_class.new(nbits)
    end

    it "clears all bits" do
      subject.set(3)
      subject.get(3).should be_true

      subject.set(7668)
      subject.get(7668).should be_true

      subject.clear

      subject.get(3).should be_false
      subject.get(7668).should be_false
    end
  end
end
