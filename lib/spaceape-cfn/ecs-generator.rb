module Spaceape
  module Cloudformation
    class EcsGenerator < Spaceape::Cloudformation::Base
      attr_accessor :service

      CONFIG_TEMPLATE = "./skel/ecs-config.yml.tmpl"
      SKEL_DIRECTORY ="./skel"
      CLUSTER_NAME = "default"

      def initialize(_, service)
        @service = service
      	@cfndsl = Pathname(File.join("ecs", @service, "#{@service}.cfndsl"))
      	json_out = "#{@service}.json"
      	@output = Pathname(File.join("ecs", @service, json_out))
      end

      def config_files
        File.join("ecs", service,'config.yml')
      end

      def generate( opts = {} )
        raise "No cfndsl template found at #{@cfndsl}" unless File.exists?(@cfndsl.to_s)
        raise "No directory found at #{@output.dirname}" unless Dir.exists?(@output.dirname)
        command = "bundle exec cfndsl #{@cfndsl} -y #{File.join("ecs", @service, "config.yml")}" 
        command += " -r #{File.join("ecs", @service, "config-helper.rb")}" if File.exists?(File.join("ecs", @service, "config-helper.rb"))
        command += " >/tmp/.#{@output.basename}.tmp"
      	puts "Generating output to #{@output}"
      	shell_out(command)
        json_output = JSON.pretty_generate(JSON.parse(File.open("/tmp/.#{@output.basename}.tmp", 'r').read))
        File.open(@output, 'w').write(json_output)
        File.unlink("/tmp/.#{@output.basename}.tmp") rescue ""
      end

      def symbol_to_template(symbol)
      	File.join(SKEL_DIRECTORY, symbol.to_s.tr('_','-') + '.tmpl')
      end

      def scaffold( opts = {}, *args )
        opts[:config_template] ||= CONFIG_TEMPLATE
        opts[:cluster_name] ||= CLUSTER_NAME

        unless args.include?("no_elb") 
          parsed_args = [ :elb_params, :ecs_service, :elb, :elb_security_group ] + args.map(&:to_sym)
        else
          opts[:config_template] = "./skel/ecs-config-no-elb.yml.tmpl"
          parsed_args = [:ecs_service_no_elb] + args.delete("no_elb").map(&:to_sym)
        end

      	components = [ :header ].concat(parsed_args)
       	components << :footer

        unless Dir.exists?(@output.dirname)
      	  puts "Creating directory #{@output.dirname}"
      	  FileUtils.mkdir_p(@output.dirname)
      	end

      	unless File.exists?(@cfndsl.to_s)
      	  puts "Generating CFNDSL skeleton"
      	  components.each do |template|
	          tmpl_file = symbol_to_template(template)
      	    raise "Invalid component specification: #{tmpl_file} does not exist." unless File.exists?(tmpl_file)
	          File.open(@cfndsl.to_s, 'a') {|f| f.write(File.read(tmpl_file)) }
	        end
        else
      	  puts "#{@cfndsl.to_s} already exists. Not re-generating,"
	      end

      	unless File.exists?(File.join("ecs", @service, 'config.yml'))
      	  puts "Generating service config file"
      	  yaml = YAML.load(File.open(opts[:config_template]))
      	  yaml["SERVICE_NAME"] = @service
      	  yaml["CLUSTER_NAME"] = opts[:cluster_name]
	        File.open(File.join("ecs", @service,'config.yml'),'w') {|f| f.write(YAML.dump(yaml)) }
      	end

        FileUtils.cp('./config-helper.rb', File.join("ecs", @service, 'config-helper.rb')) unless args.include?("no_elb")

   end

      private


    end
  end
end
