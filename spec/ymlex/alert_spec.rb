#!/usr/bin/env ruby
require 'spec_helper'

describe Alert do
  before(:each) do
    contact = { "rd" => "Richard",
                "qa" => "Quick",
                "op" => "Ohmygod", }
    level = {"rd"=>"error", "op"=>"warning", "qa"=>"info"}
    @alt = Alert.new contact, level
  end
  context "initialize" do
    it "should get default level" do
      contact = { "rd" => "Richard",
                  "qa" => "Quick",
                  "op" => "Ohmygod", }
      a = Alert.new contact
      a.default_level["rd"].should == nil
    end

    it "should recevie default level" do
      @alt.default_level["rd"].should == "error"
    end
  end

  context "get_alert" do
    it "should get default level" do
      level = { "rd" => "info", 
                "op"=>nil, 
                "qa"=>"info", 
                "remind_interval_second" => 1}
      a = @alt.get_alert level
      a["max_alert_times"].should == 2
      a["remind_interval_second"].should == 1
      a["sms"].should == ""
      a["mail"].should == "Quick;Richard;"
    end
    it "should get merged level" do
      a = @alt.get_alert
      a["max_alert_times"].should == 2
      a["sms"].should == "Richard;"
      a["mail"].should == "Quick;Ohmygod;Richard;"
    end
  end

end
