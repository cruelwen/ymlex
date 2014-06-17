# Ymlex Noah监控3.0监控配置管理工具

## 安装
考虑到涉及argus的设计，未发布到rubygems.org，需要手工安装。

### 使用gem安装
```bash
git clone http://gitlab.baidu.com/wenli/ymlex.git
cd yelex
gem build .gemspec
gem install ymlex-1.0.1.gem # 版本号可能不同
```

### 使用bundle管理
```ruby
# Gemfile
gem "ymlex", :git => "http://gitlab.baidu.com/wenli/ymlex.git"
```
```bash
bundle install 
```

## 使用

### 快速一个产品线
```bash
ymlex -a product_name
```
产品线的ymlex配置必须在"http://gitlab.baidu.com/sdc-monitor/"
此命令会在当前目录生成output目录，在其中拉取最新的Ymlex配置（git）和Argus配置（svn），执行整个产品线的配置转化，并最终给出svn的diff。
如果output目录存在，则会尝试先pull/up。
注意： 
1. *在确认更新内容后，需要手工ci才能生效！*
2. *自动更新不会删除原有的监控项目，如需删除必须手工删除。*

### 其他命令
```bash
# 将完整的yml打印在标准输出
ymlex -y some.yex
# 将instacne文件打印在标准输出，且制定模板路径
ymlex -t template_path -j some.yex 
# 对所有yex文件，在指定目录生成arugs需要的Json配置
ymlex -o output_path *.yex
# 对整个产品线目录进行转换
ymlex -t template_path -p product_path -o outpu_path
# 从Argus的日志监控转到Ymlex
ymlex -l xxx.log.conf
```

### 在ruby内调用
```ruby
require "ymlex"
# Ymlex.initLogger logger 默认logger为标准输出
# Ymlex.initTptDir "path_to_template" 默认为和输入文件同路径
hash = Ymlex.load_file "path_to_file"

# 使用ArgusYml实例
ags = ArgusYml.new "path_to_file"
puts ags.info_yml
puts ags.instance
puts ags.logs
ags.dump_json # 写入本地文件

# 转换整个文件夹
ArgusYml.process_dir ymlex_dir, json_dir
```

## Ymlex - 扩展Yml
一个Yml语法的扩展，用于快速生产Yml配置，支持：
* 继承
* 变量替换

# ArgusYml - Argus监控的YML格式描述
一个面向Argus的变体描述，特性：
* 使用YML，而非JSON
* 面向模块，而非BNS
* 极端简化语法

## 继承
Yml模板(就是标准的YML)
```yml
a: "a"
b: "b"
c: 
  ca: "ca"
  cb: "cb"
```
继承：
```yml
_inherig: template.yml
a: "a_new"
c: 
  ca: "ca_new"
d: "d_new"
```
结果：
```yml
a: "a_new"
b: "b"
c: 
  ca: "ca_new"
  cb: "cb"
d: "d_new"
```
特性：
* 不只是当前层Merge，而是对所有Hash都会Merge
* 支持递归继承（没处理遇到环的情况）
* 支持在不同层进行多重继承，仅对当前层有效

## 变量替换
```yml
a: "/home"
b: "${a}/user"
c: 
  ca: "/var"
  cb: "${c.ca}/lib"
```
结果
```yml
a: "/home"
b: "/home/user"
c: 
  ca: "/var"
  cb: "/var/lib"
```
## 简化语法示例
```yml
name: someapp
anytag: anyvalue # 扩展tag，用来作别的事情
bns:
- somebns
contacts:
  rd: somebody
  op: somebody
  qa: somebody
basepath: /home/work/somepath
_inherit: apache.tpt # 用模板继承来简化
proc:
  main:
    path: ${basepath}/bin/${name} # 使用变量替换简化代码
    alert: # 定义alert，重载默认的alert规则 
      rd: info # 针对不同的用户角色定义报警优先级，报警优先级决定是否报短信 
      op: error
request:
  listen:
    port: 8080 # 默认的监控策略都不需要写，会直接生成
log:
  accessLog:
    path: ${basepath}/logs/access_log.`%Y%m%d%H`
    flow:
      match_str: ".*"
      formula: "@{self}.cps > 1000" # @{self}会拼接出someapp_log_accessLog_flow
```
