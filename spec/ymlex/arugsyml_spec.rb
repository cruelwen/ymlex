#!/usr/bin/env ruby
require 'spec_helper'

describe ArgusYml do
  before(:each) do
    contact = { "rd" => "Richard",
                "qa" => "Quick",
                "op" => "Ohmygod", }
    level = {"rd"=>"error", "op"=>"warning", "qa"=>"info"}
    @ags = ArgusYml.new({ "name" => "test",
                          "bns" => ["b1","b2"],
                          "contacts" => contact,
                          "alert" => level })
  end

  context "initialize" do
    it "should initialize" do
      @ags.name.should == "test"
    end
  end

  context "yml to json" do
    it "should trans proc" do
      proc = { "main" => { "path" => "/home/work/test",
                           "threadNum" => { "formula" => "something > 0" }}} 
      @ags.reset_instance
      @ags.trans_proc proc
      @ags.instance["raw"].should == [{ "name"=>"test_proc_main", 
                                        "cycle"=>60, 
                                        "method"=>"noah", 
                                        "target"=>"procmon", 
                                        "params"=>"/home/work/test" }]
      @ags.instance["rule"].should == [{ "name"=>"test_proc_main_threadNum",
                                         "formula"=>"something > 0",
                                         "filter"=>"3/3",
                                         "alert"=>"test_proc_main_threadNum"}]
      @ags.instance["alert"][0]["name"].should == "test_proc_main_threadNum"
    end

    it "should trans request" do
      request = { "listen" => { "port" => 8080,
                                "cycle" => 60,
                                "protocol" => "tcp",
                                "req_type" => "port" }}
      @ags.reset_instance
      @ags.trans_request request
      @ags.instance["raw"].should == [{ "name"=>"test_request_listen_port", 
                                        "cycle"=>60, 
                                        "protocol" => "tcp",
                                        "req_type" => "port", }]
      @ags.instance["rule"].should == [{ "name"=>"test_request_listen_port",
                                         "formula"=>"test_request_listen_port != 'ok'",
                                         "filter"=>"3/3",
                                         "alert"=>"test_request_listen_port"}]
      @ags.instance["alert"][0]["name"].should == "test_request_listen_port"
    end
  end

  context "dump json" do
    it "should dump" do
      @ags.dump_json "/tmp/ymlex_test"
    end
  end

end
