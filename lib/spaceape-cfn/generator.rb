module Spaceape
  module Cloudformation
    class Generator < Spaceape::Cloudformation::Base
      attr_accessor :service
      attr_accessor :env

      GAME = "trex"
      CONFIG_TEMPLATE = "./skel/config.yml.tmpl"
      SKEL_DIRECTORY ="./skel"

      def initialize(service, env)
        super
      	@cfndsl = Pathname(File.join(@service, "#{@service}.cfndsl"))
      	json_out = "#{@service}.json"
      	@output = Pathname(File.join(@service, @env, json_out))
      end

      def config_files
        [ File.join(service,'config.yml'), File.join(service, env,  "#{env}.yml") ].select {|f| File.exists?(f)}
      end

      def generate( opts = {} )
        raise "No cfndsl template found at #{@cfndsl}" unless File.exists?(@cfndsl.to_s)
	      raise "No directory found at #{@output.dirname}" unless Dir.exists?(@output.dirname)
      	opts[:config_helper] ||= File.join(@service, '/config-helper.rb')
        command = "bundle exec cfndsl #{@cfndsl} -y #{config_files.join(" -y ")} -r #{opts[:config_helper]} >/tmp/.#{@output.basename}.tmp"
      	puts "Generating output to #{@output}"
      	shell_out(command)
        json_output = JSON.pretty_generate(JSON.parse(File.open("/tmp/.#{@output.basename}.tmp", 'r').read))
        File.open(@output, 'w').write(json_output)
      end

      def symbol_to_template(symbol)
      	File.join(SKEL_DIRECTORY, symbol.to_s.tr('_','-') + '.tmpl')
      end

      def scaffold( opts = {}, *args )
        opts[:config_template] ||= CONFIG_TEMPLATE
        opts[:game] ||= GAME
      	missing_params = []
      	parsed_args = []

        if args.include?("as_group_with_elb")
	        args.delete("as_group_with_elb")
      	  parsed_args = [ :elb, :elb_security_group, :autoscaling_group  ].concat(args.map {|x| x.to_sym})
        elsif args.include?("as_group_no_elb")
      	  args.delete("as_group_no_elb")
      	  parsed_args = [ :autoscaling_group_no_elb ].concat(args.map {|x| x.to_sym})
      	else
      	  parsed_args = args.map{|x| x.to_sym}
      	end

      	components = [ :header, :params ].concat(parsed_args)
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

    	    if opts[:autoparam]
	          # Read the CFN template and determine which params have yet to be defined
    	      missing_params = detect_missing_params(File.open(@cfndsl.to_s, 'r'))
	        end
        else
      	  puts "#{@cfndsl.to_s} already exists. Not re-generating,"
	      end

      	unless File.exists?(File.join(@service,'config.yml'))
      	  puts "Generating service-wide config"
      	  yaml = YAML.load(File.open(opts[:config_template]))
      	  yaml["STACK_NAME"] = @service
	  
      	  if opts[:autoparam]
            missing_params = missing_params - yaml.keys
          end

	        File.open(File.join(@service,'config.yml'),'w') {|f| f.write(YAML.dump(yaml)) }
      	end

      	unless File.exists?(File.join(@service, @env, "#{@env}.yml"))
      	  puts "Generating environment-specific config for #{@env}"
      	  game_prefix = opts[:game] == "siege" ? "" : "#{opts[:game]}-"
      	  yaml = { "ENVIRONMENT" => "#{game_prefix}#{@env}" }
	  
      	  if opts[:autoparam]
            missing_params = missing_params - yaml.keys
            missing_params.each{ |param| yaml[param] = "" }
          end

	        File.open(File.join(@service, @env, "#{@env}.yml"), 'w') {|f| f.write(YAML.dump(yaml)) }
      	end

      	FileUtils.cp('./config-helper.rb', File.join(@service, 'config-helper.rb'))   
   end

      private

      def detect_missing_params(skel)
        references = []
      	resources = []

      	skel.each_line do |l|
          references.concat( l.split(/Ref\s*\(/).map{ |ref| if ref.include? ")" then ref.split(")").first else [] end }) if l.match(/Ref\s*\(/)
          resources.concat( l.split(/Resource\s*\(/).map{ |ref| if ref.include? ")" then ref.split(")").first else [] end }) if l.match(/Resource\s*\(/)
        end

        return (references - resources).map{ |r| underscore(r)}
      end

      def underscore(s)
        s.gsub(/::/, '/').
      	gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
      	gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").upcase.delete("\"'")
      end
    end
  end
end
