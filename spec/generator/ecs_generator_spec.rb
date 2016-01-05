require 'spec_helper'

class ComposeECS
  def generate
    return true
  end
end

describe Spaceape::Cloudformation::Generator do
  before do
    Spaceape::Cloudformation::Base::SKEL_DIRECTORY = File.expand_path('../../mock_skels', __FILE__) 
    Spaceape::Cloudformation::Base::GAME = File.expand_path('../../mock_skels', __FILE__) 
    @generator = Spaceape::Cloudformation::EcsGenerator.new("ecs", "myService")
  end

  after(:each) do
    %x[rm -rf ecs/myService 2>/dev/null]
  end

  describe 'initialize' do
    it "should initialize itself and default to us-east-1 region" do
      @generator.region.equal?("us-east-1")      
      @generator.service.equal?("myService")
    end

    it 'should initialize itself with a different region if provided' do
      @generator = Spaceape::Cloudformation::EcsGenerator.new("ecs", "myService", "myRegion")
      @generator.region.equal?("myRegion")
      @generator.service.equal?("myService")
    end
  end

  describe 'scaffold' do
    it 'should generate a cfndsl file in the correct location' do
      allow(@generator).to receive(:parse_config_yaml).and_return(Hash.new)
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to receive(:open).exactly(6).times.ordered.with("ecs/myService/myService.cfndsl", "a")
      expect(File).to receive(:open).once.ordered.with("ecs/myService/config.yml", "w")
      @generator.scaffold
    end

    it 'should not overwrite pre-existing cfndsl or config files' do
      allow(@generator).to receive(:parse_config_yaml).and_return(Hash.new)
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to_not receive(:open).with("ecs/myService/myService.cfndsl", "a") 
      expect(File).to_not receive(:open).with("ecs/myService/config.yml", "w")
      %x[mkdir -p ecs/myService && touch ecs/myService/myService.cfndsl && touch ecs/myService/config.yml && touch ecs/myService/myEnv.yml]
      @generator.scaffold
    end

    it 'should set the SERVICE_NAME parameter in config.yml' do
      @buf = StringIO.new()
      allow(@generator).to receive(:parse_config_yaml).and_return({"SERVICE_NAME" => "wrong"})
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to receive(:open).exactly(6).times.ordered.with("ecs/myService/myService.cfndsl", "a")
      allow(File).to receive(:open).with("ecs/myService/config.yml", "w").and_yield(@buf)
      @generator.scaffold
      expect(@buf.string).to match("SERVICE_NAME: myService")
    end

  end

  describe 'generate' do
    it 'should generate a json file in the correct place' do
      compose = instance_double(ComposeECS)
      @buf = StringIO.new()
      %x[ mkdir -p ecs/myService && touch ecs/myService/myService.cfndsl && touch ecs/myService/config.yml ]
      %x[ touch ecs/myService/config-helper.rb ecs/myService/docker-compose.yml ]
      expect(@generator).to receive(:shell_out).and_return("")  
      expect(File).to receive(:open).with("ecs/myService/docker-compose.yml", "r").and_return(@buf)
      expect(File).to receive(:open).with("/tmp/.myService.json.tmp", "r").and_return(@buf)
      allow(JSON).to receive(:parse).and_return(Array.new)
      expect(File).to receive(:open).once.ordered.with("ecs/myService/myService.json", "w").and_return(@buf)
      @generator.generate
    end

    it 'should convert docker-compose to task-definition' do
      @buf = StringIO.new()
      %x[ mkdir -p ecs/myService && touch ecs/myService/myService.cfndsl && touch ecs/myService/config.yml ]
      %x[ touch ecs/myService/config-helper.rb ecs/myService/docker-compose.yml ]
      expect(@generator).to receive(:shell_out).and_return("")
      expect(File).to receive(:open).with("/tmp/.myService.json.tmp", "r").and_return(@buf)
      allow(JSON).to receive(:parse).and_return(Array.new)
      expect(File).to receive(:open).once.ordered.with("ecs/myService/myService.json", "w").and_return(@buf)
      expect_any_instance_of(ComposeECS).to receive(:new).with("")
      @generator.generate
    end
  end
end
