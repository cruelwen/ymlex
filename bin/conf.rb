#!/usr/bin/env ruby
require 'yaml'
require 'json'

filename = ARGV[0]

log_js = {}
File.open(filename,"r") do |f|
  log_js = JSON.parse f.read
end

log_yml = {}
log_yml["path"] = log_js["log_filepath"]
log_js["item"].each do |item|
  name = item["item_name_prefix"]
  item.delete "item_name_prefix"
  log_yml[name] = item
end

puts log_yml.to_yaml

