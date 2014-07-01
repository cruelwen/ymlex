#!/usr/bin/env ruby
class Alert
  # level definition
  # nil: no alert
  # info: mail
  # warning: summury and sms
  # error: sms
  # fatal: sms to boss 
  attr :contacts, :default_level
  def initialize contacts, level=nil
    @oncall = "g_ecomop_maop_oncall"
    @manager = "g_ecomop_maop_manager"
    @contacts = contacts
    @default_level = level || {"rd"=>"err", "op"=>"warn", "qa"=>nil}
  end

  def get_alert lvl=nil
    level = lvl ? @default_level.merge(lvl) : @default_level

    mail = ""
    sms = ""
    level.each do |role, lvl|
      if ["op","rd","qa"].include? role
        mail = "#{@contacts[role]};#{mail}" if lvl != nil
        if lvl =~ /err/ or lvl =~ /fatal/ or (lvl =~ /warn/ and role != "op")
          sms = "#{@contacts[role]};#{sms}" 
        end
      end
    end
    lvl = level["op"]
    sms = "#{@oncall};#{sms}" if lvl =~ /warn/ or lvl =~ /err/ or lvl =~ /fatal/
    sms = "#{@manager};#{sms}" if lvl =~ /fatal/

    remind_time = (lvl =~ /fatal/)? "300" : "7200"
    alt = {
      "max_alert_times" => level["max_alert_times"] || "2",
      "alert_threshold_percent" => level["alert_threshold_percent"] || "0",
      "sms_threshold_percent" => level["sms_threshold_percent"] || "0",
      "remind_interval_second" => level["remind_interval_second"] || remind_time,
      "mail" => mail,
      "sms" => sms,
    }
    if lvl =~ /warn/
      alt["level1_upgrade_interval"] = "10800"
      alt["level1_upgrade_sms"] = @contacts["op"]
      alt["level2_upgrade_interval"] = "36000"
      alt["level2_upgrade_sms"] = @manager
    end
    if lvl =~ /err/
      alt["level1_upgrade_interval"] = "10800"
      alt["level1_upgrade_sms"] = @manager
    end
    alt
  end

  def get_mail lvl=nil
    alert_info = get_alert lvl
    alert_info["mail"]
  end

  def get_sms lvl=nil
    alert_info = get_alert lvl
    alert_info["sms"]
  end

end

class ArgusYml

  def self.process_dir dir_path, dest_path, product = nil
    filelist = `find #{dir_path} -type f -name '*yex'`.split(' ')
    product = File.basename dir_path if !product
    filelist.each do |ymx|
      puts "process #{ymx}"
      ags = ArgusYml.new ymx, product
      ags.dump_json dest_path
    end
  end

  attr_reader :info_yml, :instance, :logs, :name, :bns, :alert, :node

  def initialize filename_or_hash, product = nil
    if filename_or_hash.kind_of? String
      yml = Ymlex.load_file filename_or_hash
    else
      yml = filename_or_hash
    end
    @info_yml = value_to_str yml
    @name = @info_yml["name"]
    @bns = @info_yml["bns"] || []
    node_list = @info_yml["node"] || []
    node_str = ""
    node_list.each {|v| node_str += v + ","}
    @node = node_str.sub /,$/, ""
    @product = product || @info_yml["product"] || @bns.first.sub(/^.*?\./,"").sub(/\..*$/,"") || "Undefined_Product"
    @product.upcase!
    @logs = {}
    @alert = Alert.new @info_yml["contacts"], @info_yml["alert"]
    @service_aggr = []
    @service_rule = []
    @service_alert = [default_alert]
    reset_instance
    trans_ytoj
  end

  def reset_instance
    @instance = empty
  end

  def value_to_str input
    case 
    when input.kind_of?(Hash)
      input.each do |k,v|
        input[k] = value_to_str v
      end
    when input.kind_of?(Array)
      input.each_index do |i|
        input[i] = value_to_str input[i]
      end
    when input.kind_of?(Fixnum) || input.kind_of?(Float)
      input = input.to_s
    end
    input
  end

  def dump_json dir_path, append_mode = true
    
    dir = "#{dir_path}/cluster/cluster.#{@name}.#{@product}.all"
    `mkdir -p #{dir}`

    # instance
    filename = "#{dir}/instance"
    if append_mode 
      old_instance = nil
      begin
        File.open(filename,"r") do |f|
          old_instance = JSON.parse f.read
        end
        old_instance = empty if !old_instance
      rescue
        old_instance = empty
      end
      new_instance = {}
      ["raw","request","rule","alert"].each do |type| 
        new_instance[type] = old_instance[type]
        next unless @instance[type]
        @instance[type].each do |new_item|
          idx = old_instance[type].find_index do |old_item| 
            old_item["name"] == new_item["name"]
          end
          if idx
            new_instance[type][idx] = new_item
          else
            new_instance[type] << new_item
          end
        end
      end 
    else
      new_instance = @instance
    end
    File.open(filename,"w") do |f|
      f.puts JSON.pretty_generate new_instance
    end

    # log
    @logs.each do |log_key, log_value|
      log_name = "#{dir}/#{log_key}.conf"
      File.open(log_name, "w") do |f|
        f.puts JSON.pretty_generate log_value
      end
    end

    # cluster
    aggr_name = "#{dir}/cluster"
    File.open(aggr_name, "w") do |f|
      cluster = { "aggr" => @service_aggr,
                  "rule" => @service_rule,
                  "alert" => @service_alert,
                }
      cluster["namespace_list"] = @bns if @bns != []
      cluster["service_node"] = @node if @node != ""
      f.puts JSON.pretty_generate cluster
    end
  end 

  def trans_ytoj
    @info_yml.each do |key, value| 
      case key
      when "proc"
        trans_proc value
      when "request"
        trans_request value
      when "exec"
        trans_exec value
      when "other"
        trans_other value
      when "log"
        trans_log value
      when "aggr"
        trans_aggr value
      end
    end
  end

  def trans_aggr list
    list.each do | rule_name, value | 
      @service_aggr << { "items" => value["items"],
                         "types" => value["types"] || "sum",
                       }
      if value["formula"]
        rule_name = "#{@name}_aggr_#{rule_name}"
        alert_name = "default_alert"
        if value["alert"]
          alt = @alert.get_alert value["alert"]
          alt["name"] = rule_name
          @service_alert << alt
          alert_name = rule_name
        end
        @service_rule << { "name" => rule_name,
                           "formula" => value["formula"],
                           "filter" => value["filter"] || "1/1",
                           "alert" => alert_name }
      end
    end
  end

  def trans_exec list
    list.each do | raw_key, raw_value |
      dft_exec_raw = { "cycle" => "60",
                       "method" => "exec",
                     }
      raw_value["name"] = "#{@name}_exec_#{raw_key}"
      @instance["raw"] << dft_exec_raw.merge(raw_value)
    end
  end

  def trans_other list
    list.each do | rule_key, rule_value |
      rule_name = "#{@name}_other_#{rule_key}"
      alert_name = "default_alert"
      if rule_value["alert"]
        alt = @alert.get_alert rule_value["alert"]
        alt["name"] = rule_name
        @instance["alert"] << alt
        alert_name = rule_name
      end
      @instance["rule"] << { "name" => rule_name,
                             "formula" => rule_value["formula"],
                             "filter" => rule_value["filter"] || "1/1",
                             "alert" => alert_name }
    end
  end

  def trans_log list
    list.each do |log_key, log_value|
      raw_name = "#{@name}_log_#{log_key}"
      log_raw = { "name" => raw_name,
                  "cycle" => log_value["cycle"] || "60",
                  "method" => "noah",
                  "target" => "logmon",
                  "params" => "${ATTACHMENT_DIR}/#{raw_name}.conf",
                }
      @instance["raw"] << log_raw

      log_conf = { "log_filepath" => log_value["path"],
                   "limit_rate" => "5",
                   "item" => []
                 }
      log_value.each do |raw_key, raw_value|
        next if raw_key == "path"
        item_name_prefix = "#{raw_name}_#{raw_key}" 
        item = { "item_name_prefix" => item_name_prefix,
                 "cycle" => raw_value["cycle"] || "60",
                 "match_str" => raw_value["match_str"],
                 "filter_str" => raw_value["filter_str"] || "",
               }
        log_conf["item"] << item
        next unless raw_value["formula"]
        alert_name = "default_alert"
        if raw_value["alert"]
          alt = @alert.get_alert raw_value["alert"]
          alt["name"] = item_name_prefix
          @instance["alert"] << alt
          alert_name = item_name_prefix
        end
        @instance["rule"] << { "name" => item_name_prefix, 
                               "formula" => raw_value["formula"],
                               "filter" => raw_value["filter"] || "1/1",
                               "alert" => alert_name,
                             }
      end
      @logs[raw_name] = log_conf
    end
  end

  def trans_proc list
    list.each do |raw_key, raw_value|
      raw_name = "#{@name}_proc_#{raw_key}"
      @instance["raw"] << { "name" => raw_name,
                            "cycle" => raw_value["cycle"]||"60",
                            "method" => "noah",
                            "target" => "procmon",
                            "params" => raw_value["path"] }
      raw_value.each do |rule_key, rule_value|
        next if (rule_key == "path" || !rule_value["formula"])
        rule_name = "#{raw_name}_#{rule_key}"
        alert_name = "default_alert"
        if rule_value["alert"]
          alt = @alert.get_alert rule_value["alert"]
          alt["name"] = rule_name
          @instance["alert"] << alt
          alert_name = rule_name
        end
        @instance["rule"] << { "name" => rule_name,
                               "formula" => rule_value["formula"],
                               "filter" => rule_value["filter"]||"3/3",
                               "alert" => alert_name }
      end
    end
  end

  def trans_request list
    list.each do |raw_key, raw_value|
      raw_name = "#{@name}_request_#{raw_key}"
      dft_raw = { "name" => raw_name,
                  "cycle" => "60",
                  "port" => "8080",
                  "protocol" => "tcp",
                  "mon_idc" => "local",
                  "req_type" => "port",
                }
      @instance["request"] << dft_raw.merge(raw_value)
      alert_name = "default_alert"
      if raw_value["alert"]
        alt = @alert.get_alert raw_value["alert"]
        alt["name"] = raw_name
        @instance["alert"] << alt
        alert_name = raw_name
      end
      @instance["rule"] << { "name" => raw_name,
                             "formula" => "#{raw_name} != 'ok'",
                             "filter" => raw_value["filter"]||"3/3",
                             "alert" => alert_name }
    end
  end

  private

  def noah_error
    {
      "name" => "noah_error",
      # "formula" => "noah_error != '' && time_between('100000-180000')",
      "formula" => "noah_error != '' && not_contain(noah_error,'logmon open log failed') ",
      "filter" => "10/10",
      "alert" => "noah_error_alert",
    } 
  end

  def default_alert
    alt = @alert.get_alert
    alt["name"] = "default_alert"
    alt
  end

  def noah_error_alert
    alt = @alert.get_alert({"rd" => nil, "qa" => nil, "op" => "warn" })
    alt["name"] = "noah_error_alert"
    alt
  end

  def empty
    {"raw"=>[], "request"=>[], "rule"=>[noah_error], "alert"=>[default_alert,noah_error_alert]}
  end

end

