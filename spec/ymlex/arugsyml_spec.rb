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

    it "should trans exec" do
      exec = { "flow" => { "target" => "/home/work/opbin/flow.sh" },
               "shell" => { "target" => "/home/work/opbin/go.sh" },
             }
      @ags.reset_instance
      @ags.trans_exec exec
      @ags.instance["raw"].should == [{ "name" => "test_exec_flow",
                                        "cycle" => 60,
                                        "method" => "exec",
                                        "target" => "/home/work/opbin/flow.sh" },
                                      { "name" => "test_exec_shell",
                                        "cycle" => 60,
                                        "method" => "exec",
                                        "target" => "/home/work/opbin/go.sh" } ]
    end

    it "should trans log" do
      log = { "accessLog" => { "path" => "/home/work/log",
                               "flow" => { "regex" => "^.*$",
                                           "formula" => "something > 1", }}}
      @ags.reset_instance
      @ags.trans_log log
      @ags.instance["raw"].should == [{ "name"=>"test_log_accessLog", 
                                        "cycle"=>60, 
                                        "method"=>"noah", 
                                        "target"=>"logmon", 
                                        "params"=>"${ATTACHMENT_DIR}/test_log_accessLog.conf" }]
      @ags.instance["rule"].should == [{ "name"=>"test_log_accessLog_flow", 
                                         "formula"=>"something > 1", 
                                         "filter"=>"3/3", 
                                         "alert"=>"test_log_accessLog_flow" }]
      @ags.instance["alert"][0]["name"].should == "test_log_accessLog_flow"
      @ags.logs.should == { "test_log_accessLog" => { "log_filepath"=>"/home/work/log", 
                                                      "limit_rate"=>5, 
                                                      "item"=>[{ "item_name_prefix"=>"test_log_accessLog_flow", 
                                                                 "cycle"=>60, 
                                                                 "match_str"=>nil, 
                                                                 "filter_str"=>"" }] }}
    end

    it "should trans other" do
      other = { "o1" => { "formula" => "o1 > 0" },
                "o2" => { "formula" => "o2 > 0" },
              } 
      @ags.reset_instance
      @ags.trans_other other
      @ags.instance["rule"][0].should == { "name" => "test_other_o1",
                                           "formula" => "o1 > 0",
                                           "filter" => "3/3",
                                           "alert" => "test_other_o1",
                                         }
      @ags.instance["rule"][1].should == { "name" => "test_other_o2",
                                           "formula" => "o2 > 0",
                                           "filter" => "3/3",
                                           "alert" => "test_other_o2",
                                         }
      @ags.instance["alert"][0]["name"].should == "test_other_o1"
      @ags.instance["alert"][1]["name"].should == "test_other_o2"
    end
  end

  context "dump json" do
    it "should work with append" do
      tmp_dir = "/tmp/ymlex_test"
      `rm -rf #{tmp_dir}`
      @ags.dump_json tmp_dir
      instance = nil
      File.open("#{tmp_dir}/service/b1/instance","r") do |f|
        instance = JSON.parse f.read
      end
      instance.should == {"raw"=>[], "rule"=>[], "alert"=>[]}

      exec = { "flow" => { "target" => "/home/work/opbin/flow.sh" }}
      @ags.reset_instance
      @ags.trans_exec exec
      @ags.dump_json tmp_dir
      File.open("#{tmp_dir}/service/b1/instance","r") do |f|
        instance = JSON.parse f.read
      end
      instance["raw"][0]["name"].should == "test_exec_flow"

      exec = { "another" => { "target" => "/home/work/opbin/flow.sh" }}
      @ags.reset_instance
      @ags.trans_exec exec
      @ags.dump_json tmp_dir
      File.open("#{tmp_dir}/service/b1/instance","r") do |f|
        instance = JSON.parse f.read
      end
      instance["raw"][0]["name"].should == "test_exec_flow"
      instance["raw"][1]["name"].should == "test_exec_another"
    end

    it "should dump log" do
      tmp_dir = "/tmp/ymlex_test"
      `rm -rf #{tmp_dir}`
      log = { "accessLog" => { "path" => "/home/work/log",
                               "flow" => { "regex" => "^.*$",
                                           "formula" => "something > 1", }}}
      @ags.reset_instance
      @ags.trans_log log
      @ags.dump_json tmp_dir
    end
  end
end
