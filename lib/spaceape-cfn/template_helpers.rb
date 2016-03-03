require 'yaml'

module Spaceape
  module Cloudformation
    module TemplateHelpers

      TRUSTED_IP_RANGES = %w[ 10.0.0.0/8 192.168.200.0/21 ]

      def self.build_security_group(config_hash)
        config_hash["TRUSTED_IP_RANGES"] ||= TRUSTED_IP_RANGES
        security_group = []
        config_hash["services"].keys.each do |service|
          rule = {}
          ext = nil
          protocol = config_hash["services"][service].fetch("protocol") { 'tcp' }
          config_hash["services"][service]["ports"].each do |port|
            if port  =~ /(?<from>\d+).-.(?<to>\d+)(\s+(?<ext>EXTERNAL))?/
              from = $~[:from]
              to = $~[:to]
              ext = $~[:ext]
            elsif port =~ /(?<from>\d+)(\s+(?<ext>EXTERNAL))?/
              from = to = $~[:from]
              ext = $~[:ext]
            else
              from = to = port
            end

            rule["FromPort"] = from
            rule["ToPort"] = to
            rule["IpProtocol"] = protocol
            ips = ext ? %w[ 0.0.0.0/0 ] : config_hash["TRUSTED_IP_RANGES"] 
            ips.each do |ip_range|
              rule["CidrIp"] = ip_range
              security_group << rule.dup
            end
          end
        end
        return security_group
      end

      def self.build_external_elb_security_group(config_hash)
        security_group = []
        config_hash["services"].keys.each do |service|
          next unless config_hash["services"][service]["listeners"]
          config_hash["services"][service]["listeners"].each do |entry|
            rule = {}
            ranges = entry.fetch('external_ranges') { %w(0.0.0.0/0) }
            if ranges == 'trusted'
              ranges = TRUSTED_IP_RANGES
            end

            ranges.each do |range|
              if entry.fetch('external') { false }
                rule["IpProtocol"] = 'tcp'
                rule["CidrIp"] = range
                rule["ToPort"] = entry.fetch('elb_port') { :missing_elb_port }
                rule["FromPort"] = entry.fetch('elb_port') { :missing_elb_port }
              end
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
            listener = {}
            entry =~ /(?<elb>\d+).-.(?<inst>\d+).?(?<proto>\w+)?/
            entry =~ /(?<elb>\d+).-.(?<inst>\d+).?(?<proto>\w+)?(.-.(?<inst_proto>\w+))?/
            if $~
              listener["LoadBalancerPort"] = $~[:elb]
              listener["InstancePort"] = $~[:inst]
              listener["Protocol"] =  $~[:proto] ? $~[:proto] : 'HTTP'
              listener["InstanceProtocol"] = $~[:inst_proto] if $~[:inst_proto]
              if config_hash["services"][service]["ssl"]
                listener["SSLCertificateId"] = config_hash["services"][service]["ssl"]["certificate"]
                listener["PolicyNames"] = config_hash["services"][service]["ssl"].fetch("policy") { [] }
              end
            else
              listener["LoadBalancerPort"] = entry.fetch('elb_port') { :missing_elb_port }
              listener["InstancePort"] = entry.fetch('instance_port') { :missing_instance_port }
              listener["Protocol"] = entry.fetch('elb_protocol') { 'HTTP' }
              listener["InstanceProtocol"] = entry.fetch('instance_protocol') { 'TCP' }
              ssl = entry.fetch('ssl') { :no_ssl }
              unless ssl == :no_ssl
                listener["SSLCertificateId"] = ssl.fetch("certificate")
                listener["PolicyNames"] = ssl.fetch("policy") { [] }
              end
            end
            # Clear the match data local variable
            $~ = nil
            listeners << listener
          end
        end
        return listeners
      end

    end
  end
end
