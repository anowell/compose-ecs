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

        puts msg + "#{stack_name} using template at #{File.join(@service, @env, "#{@service}.json")} with policy #{policy}"
        cfn = setup_amazon('CloudFormation::Client', @aws_config, @region)  
        cfn.method(method).call(opts)
      end

    end
  end
end
