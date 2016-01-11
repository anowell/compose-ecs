require 'spec_helper'

describe Spaceape::Cloudformation::LaunchConf do
  before do
    %x[mkdir -p launch_configs/myType && echo '{}' > launch_configs/myType/myType.cfndsl; echo 'AMI_PROFILE: default' > launch_configs/myType/config.yml;]
    Spaceape::Cloudformation::LaunchConf::AMI_MAP = File.expand_path('../../mock_skels/amis.yml', __FILE__) 
    @launchconf = Spaceape::Cloudformation::LaunchConf.new("", "myType")
  end

  after(:each) do
    %x[rm -rf launch_configs 2>/dev/null]
  end

  describe 'initialize' do
    it "should initialize itself and default to us-east-1 region" do
      @launchconf.region.equal?("us-east-1")      
      @launchconf.type.equal?("myType")
    end

    it 'should initialize itself with a different region if provided' do
      @launchconf = Spaceape::Cloudformation::LaunchConf.new("", "myType", "myRegion")
      @launchconf.region.equal?("myRegion")
      @launchconf.type.equal?("myType")
    end
  end

  describe 'generate' do
    it 'should generate a JSON template in the correct location' do
      @buf = StringIO.new()
      expect(File).to receive(:open).once.ordered.with("/tmp/.myType.json.attrs.tmp", "w")
      expect(@launchconf).to receive(:shell_out).and_return(true)
      expect(File).to receive(:open).once.ordered.with("/tmp/.myType.json.tmp", "r").and_return(@buf)
      allow(JSON).to receive(:parse).and_return(Array.new)
      expect(File).to receive(:open).once.ordered.with("launch_configs/myType/us-east-1/myType.json","w").and_return(@buf)
      @launchconf.generate
    end

    it 'should generate a JSON template in the correct region-specific location' do
      @buf = StringIO.new()
      @launchconf = Spaceape::Cloudformation::LaunchConf.new("", "myType", "myRegion")
      expect(File).to receive(:open).once.ordered.with("/tmp/.myType.json.attrs.tmp", "w")
      expect(@launchconf).to receive(:shell_out).and_return(true)
      expect(File).to receive(:open).once.ordered.with("/tmp/.myType.json.tmp", "r").and_return(@buf)
      allow(JSON).to receive(:parse).and_return(Array.new)
      expect(File).to receive(:open).once.ordered.with("launch_configs/myType/myRegion/myType.json","w").and_return(@buf)
      @launchconf.generate
    end

#    it 'should infer the correct AMI from the AMI_PROFILE' do
#      @buf = StringIO.new()
#      @conf = StringIO.new(File.read("launch_configs/myType/config.yml")) 
#      expect(File).to receive(:open).once.with("/tmp/.myType.json.attrs.tmp", "w").and_yield(@buf)
#      allow(File).to receive(:open).once.ordered.with("launch_configs/myType/config.yml", "r:bom|utf-8")
#      allow(File).to receive(:open).once.ordered.with("/Users/louismccormack/src/spaceape/spaceape-cfn/spec/mock_skels/amis.yml", "r:bom|utf-8")
#      expect(@launchconf).to receive(:shell_out).and_return(true)
#      expect(File).to receive(:open).once.ordered.with("/tmp/.myType.json.tmp", "r")#.and_return(StringIO.new)
#      allow(JSON).to receive(:parse).and_return(Array.new)
#      expect(File).to receive(:open).once.ordered.with("launch_configs/myType/myRegion/myType.json","w")#.and_return(StringIO.new)
#      @launchconf.generate
#      expect(@buf.string).to match("AMI: ami-12345678")
#    end

  end
end
