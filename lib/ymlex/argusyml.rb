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
    @contacts = contacts
    @default_level = level || {"rd"=>nil, "op"=>nil, "qa"=>nil}
  end

  def get_alert lvl=nil
    level = lvl ? @default_level.merge(lvl) : @default_level
    mail = ""
    sms = ""
    level.each do |role, lvl|
      if ["op","rd","qa"].include? role
        mail = "#{@contacts[role]};#{mail}" if lvl
        sms = "#{@contacts[role]};#{sms}" if lvl == "error" or lvl == "fatal"
      end
    end
    {
      "max_alert_times" => level["max_alert_times"] || "2",
      "alert_threshold_percent" => level["alert_threshold_percent"] || "0",
      "sms_threshold_percent" => level["sms_threshold_percent"] || "0",
      "remind_interval_second" => level["remind_interval_second"] || "0",
      "mail" => mail,
      "sms" => sms,
    }
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

  def self.process_dir dir_path, dest_path
    filelist = `find #{dir_path} -type f -name '*yex'`.split(' ')
    filelist.each do |ymx|
      ags = ArgusYml.new ymx
      ags.dump_json dest_path
    end
  end

  attr_reader :info_yml, :instance, :logs, :name, :bns, :alert, :aggr

  def initialize filename_or_hash
    if filename_or_hash.kind_of? String
      yml = Ymlex.load_file filename_or_hash
    else
      yml = filename_or_hash
    end
    @info_yml = value_to_str yml
    @name = @info_yml["name"]
    @bns = @info_yml["bns"]
    @logs = {}
    @aggr = []
    @alert = Alert.new @info_yml["contacts"], @info_yml["alert"]
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
    @bns.each do |bns_name|
      dir = "#{dir_path}/service/#{bns_name}"
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

      # aggr
      aggr_name = "#{dir}/service"
      new_service = @aggr
      if append_mode 
        old_service = nil
        begin
          File.open(aggr_name,"r") do |f|
            old_instance = (JSON.parse f.read)["aggr"]
          end
        rescue
          old_instance = nil
        end
        new_service = (new_service + old_instance).uniq if old_instance
      end
      File.open(aggr_name, "w") do |f|
        f.puts JSON.pretty_generate({ "aggr" => new_service })
      end
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
    @aggr = list
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
                             "alert" => rule_name }
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
      "formula" => "noah_error != '' ",
      "filter" => "10/10",
      "alert" => "default_alert",
    } 
  end

  def default_alert
    alt = @alert.get_alert
    alt["name"] = "default_alert"
    alt
  end

  def empty
    {"raw"=>[], "request"=>[], "rule"=>[noah_error], "alert"=>[default_alert]}
  end

end

