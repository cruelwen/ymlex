#!/usr/bin/env ruby

module Ymlex

  def Ymlex.parse input, tptDir
    input.each do |key,value|
      if value.class == Hash 
        input[key] = parse value, tptDir
      end
    end
    if input.key? "_inherit"
      father = load_file File.join(tptDir,input["_inherit"])
      input.delete "_inherit"
      input = merge father, input
    end
    input
  end

  def Ymlex.verblize input, ref
    case 
    when input.class == Hash
      input.each do |key,value|
        input[key] = verblize value, ref
      end
    when input.class == Array
      input.each_index do |i|
        input[i] = verblize input[i], ref
      end
    when input.class == String
      input = verbString input, ref
    end
    input
  end

  def Ymlex.verbString input, ref
    reg = /\${(.*?)}/.match(input)
    while reg
      toRep = reg[1] if reg
      toEval = toRep.gsub(/[\.]/,"\"][\"").sub(/^/,"ref[\"").sub(/$/,"\"]")
      begin 
        resultEval = eval toEval
      rescue
        resultEval = ""
        # TODO
      end
      input = input.sub(/\${(.*?)}/,resultEval)
      reg = /\${(.*?)}/.match(input)
    end
    input
  end

  def Ymlex.merge father, child
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
      father[key] = value if !father.key? key
    end
    father
  end

  def Ymlex.load_file file, tptDir=nil
    input = YAML.load_file file
    tptDir = File.dirname file if tptDir==nil
    input = parse input, tptDir
    verblize input, input
  end
end
