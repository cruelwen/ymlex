#!/usr/bin/env ruby

class Ymlex

  @log = Logger.new STDOUT
  @log.level = Logger::WARN

  def self.initLogger logger
    @log = logger
  end

  def self.getLogger
    @log
  end

  def self.initTptDir dir
    @tptDir = dir
  end

  def self.getTptDir
    @tptDir
  end

  def self.load_file file
    loadFile file
  end

  def self.loadFile file
    @log.debug "start load file: #{file}"
    input = YAML.load_file file
    @tptDir ||= File.dirname file
    input = parse input
    @log.debug "after parse, #{file} is #{input}"
    input = verblize input
    @log.debug "after verblize, #{file} is #{input}"
    input
  end

  def self.loadTpt file
    input = YAML.load_file file
    @tptDir ||= File.dirname file
    input = parse input
    input
  end

  def self.parse input
    input.each do |key,value|
      if value.class == Hash 
        input[key] = parse value
      end
    end
    if input.key? "_inherit"
      father = loadTpt File.join(@tptDir,input["_inherit"])
      input.delete "_inherit"
      input = merge father, input
    end
    input
  end

  def self.verblize input, ref = nil, selfRule = ""
    ref ||= input
    case 
    when input.class == Hash
      input.each do |key,value|
        input[key] = verblize value, ref, "#{selfRule}_#{key}"
      end
    when input.class == Array
      input.each_index do |i|
        input[i] = verblize input[i], ref, selfRule
      end
    when input.class == String
      input = verbString input, ref, selfRule
    end
    input
  end

  def self.verbString input, ref, selfRule
    @log.debug "verbString #{input},ref is #{ref}"
    input = input.gsub(/\${self}/, selfRule)
    reg = /\${(.*?)}/.match(input)
    while reg
      toRep = reg[1]
      toEval = toRep.gsub(/[\.]/,"\"][\"").sub(/^/,"ref[\"").sub(/$/,"\"]")
      begin
        resultEval = eval toEval
      rescue
        @log.error "fail to verbString #{input}"
        raise "fail to verbString #{input}"
      end
      input = input.sub(/\${(.*?)}/,resultEval)
      reg = /\${(.*?)}/.match(input)
    end

    input
  end

  def self.merge father, child
    father.each do |key,value|
      if child.key? key
        if value.class == Hash && child[key].class == Hash
          father[key] = merge value, child[key]
        elsif value.class == Array && child[key].class == Array
          father[key] = (value + child[key]).uniq
        else
          father[key] = child[key]
        end
      end
    end
    child.each do |key,value|
      father[key] ||= value
    end
    father
  end

end
