require 'json'
require 'spaceape-lib'

module Spaceape
  module Cloudformation
    class EcsUploader < Spaceape::Cloudformation::Base
      attr_accessor :region
      attr_accessor :aws_config

      include Spaceape::AWS

      DEFAULT_LOCKED_POLICY = "policies/ecs-locked.json"
      DEFAULT_UNLOCKED_POLICY = "policies/unlock-all.json"
      AWS_CONFIG = '~/.aws/config'

      def initialize(_, service, region='us-east-1', aws_config=AWS_CONFIG)
        @service = service
        @stack_name = "ecs-#{service}"
        @aws_config = aws_config
        @region = region
        check_json(File.join("ecs", @service, "#{@service}.json"))
        check_json(File.join("ecs", @service, "task-definition.json")) if File.exists?(File.join("ecs", @service, "task-definition.json"))
        check_json(File.join("ecs", @service, "volumes.json")) if File.exists?(File.join("ecs", @service, "volumes.json"))
      end

      def check_json(json)
        JSON.parse(File.open(json).read)
      rescue Errno::ENOENT, JSON::ParserError
  	      raise "JSON template #{json} does not exist or is not valid JSON."
      end

      def update_task_definition
        cmd = "aws ecs register-task-definition --cli-input-json file://#{File.join("ecs", @service, "task-definition.json")}" 
        cmd += " --volumes file://#{File.join("ecs", @service, "volumes.json")}" if File.exists?(File.join("ecs", @service, "volumes.json"))
        puts "Running command: #{cmd}"
        shell_out(cmd)
        puts "Created task definition #{@service}:#{get_latest_revision_stripped}"
      end

      def update_taskdef_in_template(revision)
        puts "Updating #{File.join("ecs", @service, "#{@service}.json")} with task definition #{revision}"
        regex = "arn:aws:ecs:.*:.*:task-definition/#{@service}:[0-9]+"
        cmd = "sed -E -i '' -e \'s|#{regex}|#{revision}|\' #{File.join("ecs", @service, "#{@service}.json")}"
        shell_out(cmd)
        cmd = "sed -i '' -e \'s|__TASKDEF__|#{revision}|\' #{File.join("ecs", @service, "#{@service}.json")}"
        shell_out(cmd)
      end

      def get_latest_revision
        @get_latest_revision ||= lambda { 
        cmd = "aws ecs list-task-definitions --family-prefix #{@service}"
        rev = JSON.parse(shell_out(cmd), symbolize_names: true)[:taskDefinitionArns].last
        puts "Found #{rev}"
        return rev
        }.call
      end

      def get_latest_revision_stripped
        get_latest_revision.split(/:/).last
      end

      def get_specific_revision(revision)
        cmd = "aws ecs list-task-definitions --family-prefix #{@service}"
        rev = JSON.parse(shell_out(cmd), symbolize_names: true)[:taskDefinitionArns].select{|x| x =~ /#{@service}:#{revision}$/}
        raise "No revision #{revision} found for #{@service}" unless rev.length == 1
        puts "Found #{rev[0]}"
        return rev[0]
      end

      def set_revision(revision)
        unless revision.nil?
          return get_specific_revision(revision) 
        else
          return get_latest_revision
        end
      end

      def create_stack(opts = {})
        opts[:policy] ||= DEFAULT_LOCKED_POLICY
        check_json(opts[:policy])
        opts[:no_taskdef] ||= false
        # Create the task definition before the stack itself
        unless opts[:no_taskdef] or opts[:revision]
          update_task_definition
        end
        update_taskdef_in_template(set_revision(opts[:revision]))
        stack_command(:create, opts[:policy])
      end

      def update_stack(opts = {})
        opts[:policy] ||= DEFAULT_LOCKED_POLICY
        check_json(opts[:policy])
        opts[:no_taskdef] ||= false
        # Update the task definition if told to do so
        if opts[:taskdef_only]
          puts "Updating task definition only."
          update_task_definition
        else
          update_task_definition unless opts[:no_taskdef] or opts[:revision]
          update_taskdef_in_template(set_revision(opts[:revision])) 
          stack_command(:update, opts[:policy])
        end
      end

      def stack_command(action, policy)
        opts = { :stack_name => @stack_name,
                 :template_body => File.open(File.join("ecs", @service, "#{@service}.json")).read,
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

        puts msg + "#{@stack_name} using template at #{File.join("ecs", @service, "#{@service}.json")} with policy #{policy}"
        cfn = setup_amazon('CloudFormation::Client', @aws_config, @region)  
        cfn.method(method).call(opts)
      end

    end
  end
end
