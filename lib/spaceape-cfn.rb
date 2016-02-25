require 'spaceape-cfn/base'
require 'spaceape-cfn/generator'
require 'spaceape-cfn/ecs-generator'
require 'spaceape-cfn/uploader'
require 'spaceape-cfn/ecs-uploader'
require 'spaceape-cfn/launch-conf'

class String
  def red;   "\033[31m#{self}\033[0m" end
  def green; "\033[32m#{self}\033[0m" end
  def cyan;  "\033[36m#{self}\033[0m" end
  def bold;  "\033[1m#{self}\033[22m" end
end
