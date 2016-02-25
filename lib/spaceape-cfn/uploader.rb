require 'json'
require 'spaceape-lib'

module Spaceape
  module Cloudformation
    class Uploader < Spaceape::Cloudformation::Base
      attr_accessor :region
      attr_accessor :aws_config
    
      include Spaceape::AWS

      DEFAULT_LOCKED_POLICY = "policies/locked.json"
      DEFAULT_UNLOCKED_POLICY = "policies/unlock-all.json"
      AWS_CONFIG = '~/.aws/config'

      def initialize(service, env, region='us-east-1', aws_config=AWS_CONFIG)
        @service = service
        @env = env
        @aws_config = aws_config
        @region = region
        check_json(File.join(@service, @env, "#{@service}.json"))
      end

      def check_json(json)
        JSON.parse(File.open(json).read)
      rescue Errno::ENOENT, JSON::ParserError
  	      raise "JSON template #{json} does not exist or is not valid JSON."
      end

      def create_stack(opts = {})
        opts[:policy] ||= DEFAULT_LOCKED_POLICY
        check_json(opts[:policy])
        stack_command(:create, opts[:stackname], opts[:policy])
      end

      def update_stack(opts = {})
        opts[:policy] ||= DEFAULT_LOCKED_POLICY
        check_json(opts[:policy])
        check_asg_size(opts[:stackname], File.join(@service, @env, "#{@service}.json")) unless opts[:no_asg_check]
        stack_command(:update, opts[:stackname], opts[:policy])
      end

      def stack_command(action, stack_name, policy)
        opts = { :stack_name => stack_name,
                 :template_body => File.open(File.join(@service, @env, "#{@service}.json")).read,
                 :capabilities => [ 'CAPABILITY_IAM' ]
	       }

        case action
        when :create
          opts[:stack_policy_body] = File.open(policy).read
          opts[:disable_rollback] = true
          msg = "Creating "
          method = :create_stack
        when :update
          opts[:stack_policy_during_update_body] = File.open(policy).read
          msg = "Updating "
          method = :update_stack
        end

        msg += "#{stack_name} using template at #{File.join(@service, @env, "#{@service}.json")} with policy #{policy}"
        puts msg.bold
        cfn = setup_amazon('CloudFormation::Client', @aws_config, @region)  
        cfn.method(method).call(opts)
      end

      # Compare the proposed maxSize of the AS group against
      # the actual size. Warn if instances will be terminated
      def check_asg_size(stackname, template)
        puts "Running ASG checks against #{stackname}. Skip with --no-asg-check".bold
        cfn = setup_amazon("CloudFormation", @aws_config, @region)
        stack = cfn.stacks[stackname] 
        as_groups = Hash.new {|k,v| k[v] = Hash.new }
        stack.resources.each do |r|
          if r.resource_type == "AWS::AutoScaling::AutoScalingGroup"
            as_groups[r.physical_resource_id]["logical_id"] = r.logical_resource_id
          end
        end

        j = JSON.parse(File.read(template))
        as = setup_amazon("AutoScaling", @aws_config, @region)
        as_groups.keys.each do |asg|
          puts "Found ASG #{asg}. Gathering information".bold
          logical = as_groups[asg]["logical_id"]
          instance_count = as.groups[asg].desired_capacity.to_i
          puts "Logical ID is #{logical}".bold
          # Gather data from the template
          max_ref = j["Resources"][logical]["Properties"]["MaxSize"]["Ref"]
          local_max = j["Parameters"][max_ref]["Default"]
          # Compare and panic!
          if local_max < instance_count
            puts "WARNING! Size of #{asg} (#{instance_count}) is larger than proposed max of #{local_max}".red
            puts "This update would result in the loss of #{instance_count - local_max} instances.".red
            puts "NOT continuing".cyan
            exit(2)
          end

          puts "Found #{instance_count} instances. OK".green
        end

        
        rescue => e
          puts "Unable to check ASG size(s) of #{stackname}: #{e}"
          exit(2)
      end

    end
  end
end
