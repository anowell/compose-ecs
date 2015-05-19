module Spaceape
  module Cloudformation
    class Generator < Spaceape::Cloudformation::Base
      attr_accessor :service
      attr_accessor :env

      GAME = "trex"
      CONFIG_TEMPLATE = "./skel/config.yml.tmpl"

      @skeleton = {
		:header => "skel/header.tmpl",
		:params => "skel/params.tmpl",
		:footer => "skel/footer.tmpl",
		:elb => "skel/elb.tmpl",
		:elb_security_group => "skel/elb-security-group.tmpl",
		:autoscaling_group => "skel/autoscaling-group.tmpl",
		:autoscaling_group_no_elb => "skel/autoscaling-group-no-elb.tmpl",
		:instance_security_group => "skel/instance-security-group.tmpl",
		:record_set => "skel/record-set.tmpl"
	}


      class << self
        attr_accessor :skeleton
      end

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
        command = "bundle exec cfndsl #{@cfndsl} -y #{config_files.join(" -y ")} -r #{opts[:config_helper]} | json_pp >#{@output}"
	puts "Generating output to #{@output}"
	shell_out(command)
      end

      def scaffold( opts = {}, *args )
        opts[:config_template] ||= CONFIG_TEMPLATE
        opts[:game] ||= GAME
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

        skel = Generator.skeleton
	unless File.exists?(@cfndsl.to_s)
	  puts "Generating CFNDSL skeleton"
	  components.each do |template|
	    raise "Invalid component specification: #{template}" unless skel[template]
	    File.open(@cfndsl.to_s, 'a') {|f| f.write(File.read(skel[template])) }
	  end
        else
	  puts "#{@cfndsl.to_s} already exists. Not re-generating,"
	end

	unless File.exists?(File.join(@service,'config.yml'))
	  puts "Generating service-wide config"
	  yaml = YAML.load(File.open(opts[:config_template]))
	  yaml["STACK_NAME"] = @service
	  File.open(File.join(@service,'config.yml'),'w') {|f| f.write(YAML.dump(yaml)) }
	end

	unless File.exists?(File.join(@service, @env, "#{@env}.yml"))
	  puts "Generating environment-specific config for #{@env}"
	  yaml = { "ENVIRONMENT" => "#{GAME}-#{@env}", "INTERNAL_ELB_NAME" => "" }
	  File.open(File.join(@service, @env, "#{@env}.yml"), 'w') {|f| f.write(YAML.dump(yaml)) }
	end

	FileUtils.cp('./config-helper.rb', File.join(@service, 'config-helper.rb'))   # Need a better way to do this
      end

    end
  end
end
