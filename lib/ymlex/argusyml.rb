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
    filelist = `cd #{dir_path} && find . -type f | grep '.ymlex'`.split(' ')
    filelist.each do |ymx|
      ags = ArgusYml.new ymx
      ags.dump_json dest_path
    end
  end

  attr_reader :info_yml, :instance, :logs, :name, :bns, :alert

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
          new_instance[type] = old_instance[type] + @instance[type] 
        end 
      else
        new_instance = @instance
      end

      File.open(filename,"w") do |f|
        f.puts JSON.pretty_generate new_instance
      end

      @logs.each do |log_key, log_value|
        log_name = "#{dir}/#{log_key}.conf"
        File.open(log_name, "w") do |f|
          f.puts JSON.pretty_generate log_value
        end
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
      when "other_rule"
        trans_other value
      when "log"
        trans_log value
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
      alt = @alert.get_alert rule_value["alert"]
      alt["name"] = rule_name
      @instance["alert"] << alt
      @instance["rule"] << { "name" => rule_name,
                             "formula" => rule_value["formula"],
                             "filter" => rule_value["filter"] || "3/3",
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
        alt = @alert.get_alert raw_value["alert"]
        alt["name"] = item_name_prefix
        @instance["alert"] << alt
        @instance["rule"] << { "name" => item_name_prefix, 
                               "formula" => raw_value["formula"],
                               "filter" => raw_value["filter"] || "3/3",
                               "alert" => item_name_prefix,
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
        next if rule_key == "path"
        rule_name = "#{raw_name}_#{rule_key}"
        alt = @alert.get_alert rule_value["alert"]
        alt["name"] = rule_name
        @instance["rule"] << { "name" => rule_name,
                               "formula" => rule_value["formula"],
                               "filter" => rule_value["filter"]||"3/3",
                               "alert" => rule_name }
        @instance["alert"] << alt
      end
    end
  end

  def trans_request list
    list.each do |raw_key, raw_value|
      type = raw_value["req_type"] || "port"
      raw_name = "#{@name}_request_#{raw_key}_#{type}"
      @instance["request"] << { "name" => raw_name,
                                "cycle" => raw_value["cycle"] || "60",
                                "port" => raw_value["port"],
                                "protocol" => raw_value["protocol"] || "tcp",
                                "req_type" => type,
                              }
      alt = @alert.get_alert raw_value["alert"]
      alt["name"] = raw_name
      @instance["rule"] << { "name" => raw_name,
                             "formula" => "#{raw_name} != 'ok'",
                             "filter" => raw_value["filter"]||"3/3",
                             "alert" => raw_name }
      @instance["alert"] << alt
    end
  end

  private

  def empty
    {"raw"=>[], "request"=>[], "rule"=>[], "alert"=>[]}
  end

end

