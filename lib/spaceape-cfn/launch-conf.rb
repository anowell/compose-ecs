require 'json'
require 'spaceape-lib'

module Spaceape
  module Cloudformation
    class LaunchConf < Spaceape::Cloudformation::Base
      include Spaceape::AWS
      attr_accessor :type
      attr_accessor :region
  
      AMI_MAP = 'launch_configs/amis.yml'
      KEYPAIR = 'launch_configs/keypair.conf'
      DEFAULT_BUCKET = 'sag-cloudformation-templates'

      def initialize(_, type, region='us-east-1', aws_config='~/.aws/config')
        @type = type
        @region = region
        @aws_config = aws_config
        @cfndsl = Pathname(File.join("launch_configs", @type, "#{@type}.cfndsl"))
        @output = Pathname(File.join(@cfndsl.dirname, @region, "#{@type}.json")) 
      end

      def parsed_config(config_file)
       # Merge the config.yml with the latest AMI and keypair info 
       c = YAML.load_file(config_file)
       c["AMI"] = YAML.load_file(AMI_MAP)[c["AMI_PROFILE"]][@region]
       c["KEYPAIR"] = File.read(KEYPAIR).chomp
       return c
      end

      def generate( opts = {} )
        config_file = File.join(@cfndsl.dirname, "config.yml")
        config_helper = File.join(@cfndsl.dirname, "config-helper.rb")
        raise "Directory #{@cfndsl.dirname} does not exist" unless Dir.exists?(@cfndsl.dirname.to_s)
        raise "No cfndsl template found at #{@cfndsl}" unless File.exists?(@cfndsl.to_s)
        raise "No config file found at #{config_file}" unless File.exists?(config_file)

        Dir.mkdir(@output.dirname) unless Dir.exists?(@output.dirname)

        tmp_conf = "/tmp/.#{@output.basename}.attrs.tmp"
        tmp_out = "/tmp/.#{@output.basename}.tmp"
        File.open(tmp_conf,'w') { |f| f.write(YAML.dump(parsed_config(config_file))) }

        command = "bundle exec cfndsl #{@cfndsl} -y #{tmp_conf} -r #{config_helper} >#{tmp_out}"
        puts "Generating output to #{@output}"
        shell_out(command)
        json_output = JSON.pretty_generate(JSON.parse(File.open("/tmp/.#{@output.basename}.tmp", 'r').read))
        File.open(@output.to_s, 'w').write(json_output)
        ensure
          File.unlink(tmp_conf) rescue ""
          File.unlink(tmp_out) rescue ""
      end

      def upload( opts = {} )
        opts[:bucket] ||= DEFAULT_BUCKET
        path = File.join("launch_configs", @type, @region, "#{@type}.json")
        raise "File #{path} does not exist." unless File.exists?(path)
        puts "S3 Uploading #{@output} to s3://#{opts[:bucket]}/#{path}"
        s3 = setup_amazon('S3', @aws_config)
        s3.buckets[opts[:bucket]].objects[path].write(@output)
        puts "Done!"
      end

    end
  end
end
