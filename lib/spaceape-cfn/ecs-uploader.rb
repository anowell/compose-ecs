require 'json'
require 'spaceape-lib'

module Spaceape
  module Cloudformation
    class EcsUploader < Spaceape::Cloudformation::Base
      include Spaceape::AWS

      DEFAULT_LOCKED_POLICY = "policies/ecs-locked.json"
      DEFAULT_UNLOCKED_POLICY = "policies/unlock-all.json"
      AWS_CONFIG = '~/.aws/config'

      def initialize(_, service, aws_config=AWS_CONFIG)
        @service = service
        @stack_name = "ecs-#{service}"
        @aws_config = aws_config
        check_json(File.join("ecs", @service, "#{@service}.json"))
        check_json(File.join("ecs", @service, "task-definition.json")) if File.exists?(File.join("ecs", @service, "volumes.json"))
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
        puts "Created task definition #{@service}:#{get_latest_revision}"
      end

      def update_taskdef_in_template(revision)
        puts "Updating #{File.join("ecs", @service, "#{@service}.json")} with task definition #{@service}:#{revision}"
        cmd = "sed -E -i '' -e s/#{@service}:[0-9]+/#{@service}:#{revision}/ #{File.join("ecs", @service, "#{@service}.json")}"
        shell_out(cmd)
        cmd = "sed -i '' -e s/__TASKDEF__/#{@service}:#{revision}/ #{File.join("ecs", @service, "#{@service}.json")}"
        shell_out(cmd)
      end

      def get_latest_revision
        @get_latest_revision ||= lambda { 
        cmd = "aws ecs list-task-definitions --family-prefix #{@service}"
        res = JSON.parse(shell_out(cmd), symbolize_names: true)
        rev = res[:taskDefinitionArns].last.split(/:/).last
        puts "Found #{@service}:#{rev}"
        return rev
        }.call
      end

      def create_stack(opts = {})
        opts[:policy] ||= DEFAULT_LOCKED_POLICY
        check_json(opts[:policy])
        opts[:no_create_taskdef] ||= false
        # Create the task definition before the stack itself
        unless opts[:no_create_taskdef] or opts[:revision]
          update_task_definition
        end
        opts[:revision] ||= get_latest_revision
        update_taskdef_in_template(opts[:revision])
        stack_command(:create, opts[:policy])
      end

      def update_stack(opts = {})
        opts[:policy] ||= DEFAULT_LOCKED_POLICY
        check_json(opts[:policy])
        opts[:task_definition] ||= false
        # Update the task definition if told to do so
        if opts[:task_definition]
          puts "Updating task definition only."
          update_task_definition
        else
          opts[:revision] ||= get_latest_revision
          update_taskdef_in_template(opts[:revision])
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
        cfn = setup_amazon('CloudFormation::Client', @aws_config)  
        cfn.method(method).call(opts)
      end

    end
  end
end
