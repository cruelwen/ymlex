#!/usr/bin/env ruby
require 'spec_helper'

describe Ymlex do
  it "Pass all samples" do
     sampleDir = File.join File.dirname(__FILE__), '../sample'
     Dir.foreach sampleDir do |filename|
       if File.extname(filename) == ".ymlex"
         puts "Parse sample #{filename}"
         sampleYmlex = File.join sampleDir, filename
         fileBase = File.basename filename, ".ymlex"
         sampleYml = File.join sampleDir, "#{fileBase}.yml"
         datYmlex = Ymlex.load_file sampleYmlex
         datYml = YAML.load_file sampleYml
         datYmlex.should == datYml
         puts "... Pass"
       end
     end
  end
  it "verbString input" do
    Ymlex.verbString("${a}", {"a" => "a_v"}).should == "a_v"
    Ymlex.verbString("${a.b}", {"a" => {"b" => "b_v"}}).should == "b_v"
  end
end
