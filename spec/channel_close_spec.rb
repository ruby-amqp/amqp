# encoding: utf-8

require File.expand_path("../spec_helper", __FILE__)

EM.describe "MQ#close(&callback)" do
  default_timeout 5

  should "take a callback which will run when we get back Channel.Close-Ok" do
    MQ.new.close do |amq|
      done
    end
  end
end
