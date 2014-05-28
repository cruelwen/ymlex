home = File.join(File.dirname(__FILE__),'..')
$LOAD_PATH.unshift(File.join(home,'lib'))

require 'ymlex'

config = YAML.load_file File.join(home,"config/ymlex.yml")
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO
$logger.datetime_format = "%Y-%m-%d %H:%M:%S"
$logger.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime} #{severity} : #{msg}\n"
end
