require 'yaml'

module Spaceape
  module Cloudformation
    module TemplateHelpers

    TRUSTED_IP_RANGES = %w[ 10.0.0.0/8 192.168.128.0/21 ]
    def self.build_security_group(config_hash)
      security_group = []
      config_hash["services"].keys.each do |service|
        rule = {}
	config_hash["services"][service]["ports"].each do |port|
	  if port  =~ /(?<from>\d+).-.(?<to>\d+)/
	    from = $~[:from]
	    to = $~[:to]
   	  else
	    from = to = port
	  end
	  rule["FromPort"] = from
	  rule["ToPort"] = to
	  rule["IpProtocol"] = 'tcp'
          TRUSTED_IP_RANGES.each do |ip_range|
	    rule["CidrIp"] = ip_range
	    security_group << rule.dup
	  end
        end
      end
      return security_group
    end

    def self.build_listeners(config_hash)
      listeners = []
      config_hash["services"].keys.each do |service|
	next unless config_hash["services"][service]["listeners"]
	config_hash["services"][service]["listeners"].each do |entry|
	  raise "Invalid listener specification" unless entry =~ /(?<elb>\d+).-.(?<inst>\d+).?(?<proto>\w+)?/
          listener = {}
	  listener["LoadBalancerPort"] = $~[:elb]
	  listener["InstancePort"] = $~[:inst]
	  listener["Protocol"] =  $~[:proto] ? $~[:proto] : 'HTTP'
	  listener["SSLCertificateId"] = config_hash["services"][service]["ssl"]["certificate"] if config_hash["services"][service]["ssl"]
	  listeners << listener
 	end
      end
      return listeners
    end

    module BoilerPlate
      def architectures
	arches = {}
	["t2.micro", "t2.small", "t2.medium", "m3.medium", "m3.large", "m3.xlarge", "m3.2xlarge", "c4.large", "c4.xlarge", "c4.2xlarge", "c4.4xlarge", "c4.8xlarge", "c3.large", "c3.xlarge", "c3.2xlarge", "c3.4xlarge", "c3.8xlarge", "g2.2xlarge", "r3.large", "r3.xlarge", "r3.2xlarge", "r3.4xlarge", "r3.8xlarge", "i2.xlarge", "i2.2xlarge", "i2.4xlarge", "i2.8xlarge", "hs1.8xlarge"].each do |arch|
	  arches[arch] = { "Arch" => "64" }
	end
        return arches
      end
    end

    end
  end
end
