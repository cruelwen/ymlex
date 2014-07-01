#!/usr/bin/env ruby

class Ymlex

  @log = Logger.new STDOUT
  @log.level = Logger::WARN
  @name = nil

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
    input = YAML.load_file file
    @name = input["name"] || nil
    @pwd = File.dirname file
    @tptDir ||= @pwd
    input = parse input
    input = verblize input
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
      if File.exist? File.join(@pwd,input["_inherit"])
        father = loadTpt File.join(@pwd,input["_inherit"])
      elsif File.exist? File.join(@tptDir,input["_inherit"])
        father = loadTpt File.join(@tptDir,input["_inherit"])
      end
      input.delete "_inherit"
      input = merge father, input
    end
    input
  end

  def self.verblize input, ref = nil, selfRule = nil
    ref ||= input
    case
    when input.class == Hash
      input.each do |key,value|
        nextRule = selfRule ? "#{selfRule}_#{key}" : key
        input[key] = verblize value, ref, nextRule
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
    selfRule = selfRule.sub(/^/, "#{@name}_") if @name
    selfRule = selfRule.sub(/_[a-zA-Z0-9]*$/, '')
    selfRule = selfRule.sub(/_[a-zA-Z0-9]*$/, '') if selfRule =~ /_proc_/
    input = input.gsub(/[\$@]{self}/, selfRule)

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

    reg = /@{(.*?)}/.match(input)
    while reg
      toRep = reg[1]
      keyStr = toRep.gsub(/\./, '_')
      keyStr = keyStr.sub(/^/, "#{@name}_") if @name
      input = input.sub(/@{(.*?)}/, keyStr)
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
        elsif child[key] == "disable"
          father.delete key
        else
          father[key] = child[key]
        end
      end
    end
    child.each do |key,value|
      father[key] ||= value if value != "disable"
    end
    father
  end

end
