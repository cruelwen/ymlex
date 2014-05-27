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
      "max_alert_times" => level["max_alert_times"] || 2,
      "alert_threshold_percent" => level["alert_threshold_percent"] || 0,
      "sms_threshold_percent" => level["sms_threshold_percent"] || 0,
      "remind_interval_second" => level["remind_interval_second"] || 0,
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
  attr_reader :infoYml, :instance, :logs, :name, :bns, :alert

  def initialize filename_or_hash
    if filename_or_hash.kind_of? String
      @infoYml = Ymlex.load_file filename_or_hash
    else
      @infoYml = filename_or_hash
    end
    @name = @infoYml["name"]
    @bns = @infoYml["bns"]
    @alert = Alert.new @infoYml["contacts"], @infoYml["alert"]
    reset_instance
    trans_ytoj
  end

  def reset_instance
    @instance = {"raw"=>[], "rule"=>[], "alert"=>[]}
  end

  def dump_json dir_path
    @bns.each do |bns_name|
      dir = "#{dir_path}/service/#{bns_name}"
      `mkdir -p #{dir}`
      File.open("#{dir}/instance","w") { |f| f.puts @instance.to_json }
    end
  end

  def trans_ytoj
    @infoYml.each do |key, value| 
      case key
      when "proc"
        trans_proc value
      when "request"
        trans_request value
=begin
      when "log"
        log_trans value
      when "exec"
        exec_trans value
      when "other_rule"
        other_trans value
=end
      end
    end
  end

  def trans_proc list
    list.each do |raw_key, raw_value|
      raw_name = "#{name}_proc_#{raw_key}"
      @instance["raw"] << { "name" => raw_name,
                            "cycle" => raw_value["cycle"]||60,
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
      raw_name = "#{name}_request_#{raw_key}_#{type}"
      @instance["raw"] << { "name" => raw_name,
                            "cycle" => raw_value["cycle"] || 60,
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

def log_trans list
  if list != nil
    if $jcontent["raw"].kind_of?NilClass
     $jcontent["raw"] = Array.new
   end
   if $jcontent["rule"].kind_of?NilClass
    $jcontent["rule"] = Array.new
  end
  if $jcontent["alert"].kind_of?NilClass
    $jcontent["alert"] = Array.new
  end
  i = 0
  loginfo = Hash.new
  list.keys.each do |log|
    params = "temp"
    list[log].keys.each do |key|
      if key == "path"
        path = list[log][key]
        loginfo["log_filepath"] = path
        loginfo["limit_rate"] = 5
        loginfo["item"] = Array.new
        i +=1
      else
        name = "#{$modu}_logmon_task_#{i}"
        params = "${ATTACHMENT_DIR}/#{$modu}.log.conf.#{i}"
        itemname = "#{$modu}_log_#{log}_#{key}"
        loginfo["item"].push({"item_name_prefix"=>itemname,"cycle"=>600,"match_str"=>list[log][key]["regex"]})
        $jcontent["raw"].push({"name"=>name,"cycle"=>60,"method"=>"noah","target"=>"logmon","params"=>params})
        formula = list[log][key]["formula"]
        $jcontent["rule"].push({"name"=>name,"formula"=>formula,"filter"=>"3/3","alert"=>"#{$modu}_default"})
      end
    end
# p loginfo
logconf = params.split('/')[-1]
$infoYml["bns"].each do |bns|
  `mkdir -p #{$tpath}/#{bns}`
  f = open("#{$tpath}/#{bns}/#{logconf}","w")
  f.puts loginfo.to_json
  f.close
end
end
end
end


def request_trans list
  if list != nil
    if $jcontent["request"].kind_of?NilClass
     $jcontent["request"] = Array.new
   end
   if $jcontent["rule"].kind_of?NilClass
    $jcontent["rule"] = Array.new
  end
  list.keys.each do |key|
    type = list[key]["req_type"]
    mon_idc = list[key]["mon_idc"]
    if type == "port"
     name = $modu + "_P_"+mon_idc+"_port"
     $jcontent["request"].push({"name"=>name,"cycle"=>60,"protocol"=>"tcp","port"=>list[key]["port"],"mon_idc"=>mon_idc,"req_type"=>type})
   else
     name = $modu + "_Y_"+mon_idc+"_port"
     $jcontent["request"].push({"name"=>name,"cycle"=>60,"protocol"=>"tcp","port"=>list[key]["port"],"mon_idc"=>mon_idc,"req_type"=>type,"req_content"=>list[key]["req_content"],"res_check"=>list[key]["res_check"]})
   end
   $jcontent["rule"].push({"name"=>name,"formula"=>"#{name} != 'ok'","filter"=>"3/3","alert"=>"#{$modu}_default"})
 end
end
end 

def exec_trans list
  if list != nil
    if $jcontent["raw"].kind_of?NilClass
     $jcontent["raw"] = Array.new
   end
   list.each_with_index{|path,i|
    name = "#{$modu}_exec_task_#{i}"
    $jcontent["raw"].push({"name"=>name,"cycle"=>600,"method"=>"exec","target"=>path})
  }
end
end

def other_trans list
  if list != nil
    if $jcontent["rule"].kind_of?NilClass
     $jcontent["rule"] = Array.new
   end
   list.keys.each do |key|
    $jcontent["rule"].push({"name"=>key,"formula"=>list[key]["formula"],"filter"=>"3/3","alert"=>"#{$modu}_default"})
  end
end
end

def alert_trans list
  if list != nil
    if $jcontent["alert"].kind_of?NilClass
     $jcontent["alert"] = Array.new
   end
   rd = list["rd"]
   op = list["op"]
   $jcontent["alert"].push({"name"=>"#{$modu}_default","max_alert_times"=>"2","alert_threshold_percent"=>"0","sms_threshold_per
    cent"=>0,"remind_interval_second"=>0,"mail"=>rd,"sms"=>op})
 end
end

end

