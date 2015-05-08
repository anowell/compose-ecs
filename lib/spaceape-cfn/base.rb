module Spaceape
  module Cloudformation
    class Base
      def initialize(service, env)
        @service = service
        @env = env
      end

      def shell_out(cmd)
        resp = %x[ #{cmd} ]
	unless $?.success?
	  raise "Error running #{cmd} : #{resp}"
	end
      end
    end
  end
end
