module Spaceape
  module Cloudformation
    class Uploader < Spaceape::Cloudformation::Base
      DEFAULT_LOCKED_POLICY = "policies/locked.json"
      DEFAULT_UNLOCKED_POLICY = "policies/unlock-all.json"

      def initialize(service, env)
	@service = service
	@env = env
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
	command = stack_command(:update, opts[:stackname], opts[:policy])
	puts "Running:\n#{command}"
	shell_out(command)
      end

      def update_stack(opts = {})
	check_json(opts[:policy])
	command = stack_command(:update, opts[:stackname], opts[:policy])
	puts "Running:\n#{command}"
        shell_out(command)
      end

      def stack_command(action, stack_name, policy)
        command = "aws cloudformation #{action.to_s}-stack --stack-name #{stack_name} --template-body file://#{File.join(@service, @env, "#{@env}.json")} --capabilities CAPABILITY_IAM "
	case action
	when :create
	  command += "--stack-policy-body file://#{policy} --disable-rollback"
	when :update
	  command += "--stack-policy-during-update-body file://#{policy}"
	end
	return command
      end
    end
  end
end
