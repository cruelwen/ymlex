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
      a.default_level["rd"].should == "err"
    end

    it "should recevie default level" do
      @alt.default_level["rd"].should == "error"
    end
  end

  context "no oncall and manager" do
    it "should get no oncall" do
      level = { "oncall" => nil }
      a = @alt.get_alert level
      a["sms"].should == ";Richard;"
    end
    it "should get no manager" do
      level = { "manager" => nil }
      a = @alt.get_alert level
      a["sms"].should == "g_ecomop_maop_oncall;Richard;"
      a["level2_upgrads_sms"] = ""
    end
  end

  context "get_alert" do
    it "should get default level" do
      level = { "rd" => "info", 
                "op"=>nil, 
                "qa"=>"info", 
                "remind_interval_second" => 1}
      a = @alt.get_alert level
      a["max_alert_times"].should == "2"
      a["remind_interval_second"].should == 1
      a["sms"].should == ""
      a["mail"].should == "Quick;Richard;"
    end
    it "should get merged level" do
      a = @alt.get_alert
      a["max_alert_times"].should == "2"
      a["sms"].should == "g_ecomop_maop_oncall;Richard;"
      a["mail"].should == "Quick;Ohmygod;Richard;"
    end
  end

end
