module Spaceape
  module Cloudformation
    GAME = "trex"
    CONFIG_TEMPLATE = "config.yml.tmpl"
    SKEL_DIRECTORY ="./skel"
    class Base
      def initialize(service, env, region='us-east-1')
        @service = service
        @env = env
        @region = region
      end

      def shell_out(cmd)
        resp = %x[ #{cmd} ]
        unless $?.success?
          raise "Error running #{cmd} : #{resp}"
      	end
        return resp
      end

      def parse_config_yaml(template)
        # Allow region-specific config to override default
        config = Hash.new
        [ File.join(SKEL_DIRECTORY,template), File.join(SKEL_DIRECTORY, @region, template) ].each do |f|
          config.merge!(YAML.load(File.open(f))) if File.exists?(f)
        end
        return config
      end

     def symbol_to_template(symbol)
        # Check region-specific directory first
        f = symbol.to_s.tr('_','-') + '.tmpl'
        locs = [ File.join(SKEL_DIRECTORY, @region, f), File.join(SKEL_DIRECTORY, f)]
        locs.each do |tmpl|
          return tmpl if File.exists?(tmpl)
        end
       raise "Invalid component specification: #{f} does not exist in #{locs.join(' or ')}."
      end
    end
  end
end
