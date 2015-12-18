require 'spec_helper'

describe Spaceape::Cloudformation::Generator do
  before do
    Spaceape::Cloudformation::Base::SKEL_DIRECTORY = File.expand_path('../../mock_skels', __FILE__) 
    Spaceape::Cloudformation::Base::GAME = File.expand_path('../../mock_skels', __FILE__) 
    @generator = Spaceape::Cloudformation::Generator.new("myService", "myEnv")
  end

  after(:each) do
    %x[rm -rf myService 2>/dev/null]
  end

  describe 'initialize' do
    it "should initialize itself and default to us-east-1 region" do
      @generator.region.equal?("us-east-1")      
      @generator.env.equal?("myEnv")
      @generator.service.equal?("myService")
    end
  end

  describe 'scaffold' do
    it 'should generate a cfndsl file in the correct location' do
      @generator.stub(:parse_config_yaml).and_return(Hash.new)
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to receive(:open).thrice.ordered.with("myService/myService.cfndsl", "a")
      expect(File).to receive(:open).once.ordered.with("myService/config.yml", "w")
      expect(File).to receive(:open).once.ordered.with("myService/myEnv/myEnv.yml", "w")
      @generator.scaffold
    end

    it 'should not overwrite pre-existing cfndsl or config files' do
      @generator.stub(:parse_config_yaml).and_return(Hash.new)
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to_not receive(:open).with("myService/myService.cfndsl", "a") 
      expect(File).to_not receive(:open).with("myService/config.yml", "w")
      expect(File).to_not receive(:open).with("myService/myEnv/myEnv.yml", "w")
      %x[mkdir -p myService/myEnv && touch myService/myService.cfndsl && touch myService/config.yml && touch myService/myEnv/myEnv.yml]
      @generator.scaffold
    end

    it 'should set the STACK_NAME parameter in config.yml' do
      @buf = StringIO.new()
      @generator.stub(:parse_config_yaml).and_return({"STACK_NAME" => "wrong"})
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to receive(:open).thrice.ordered.with("myService/myService.cfndsl", "a")
      expect(File).to receive(:open).once.ordered.with("myService/myEnv/myEnv.yml", "w")
      allow(File).to receive(:open).with("myService/config.yml", "w").and_yield(@buf)
      @generator.scaffold
      expect(@buf.string).to match("STACK_NAME: myService")
    end

    it 'should set the correct environment' do
      @buf = StringIO.new()
      @generator.stub(:parse_config_yaml).and_return({"STACK_NAME" => "wrong"})
      allow(::FileUtils).to receive(:cp).and_return(true)
      expect(File).to receive(:open).thrice.ordered.with("myService/myService.cfndsl", "a")
      expect(File).to receive(:open).once.ordered.with("myService/config.yml", "w")
      allow(File).to receive(:open).with("myService/myEnv/myEnv.yml", "w").and_yield(@buf)
      @generator.scaffold({:game => "test"})
      expect(@buf.string).to match("ENVIRONMENT: test-myEnv")
    end
  end

  describe 'generate' do
    it 'should generate a json file in the correct place' do
      @buf = StringIO.new()
      %x[ mkdir -p myService/myEnv && touch myService/myService.cfndsl && touch myService/config.yml && touch myService/myEnv/myEnv.yml ]
      %x[ touch myService/config-helper.rb ]
      allow(File).to receive(:open).with("/tmp/.myService.attrs.tmp").and_yield(@buf)
      @generator.stub(:parsed_config).and_return(Hash.new)  
      @generator.stub(:shell_out).and_return("")  
      expect(File).to receive(:open).once.ordered.with("/tmp/.myService.json.attrs.tmp", "w")
      allow(File).to receive(:open).with("/tmp/.myService.json.tmp", "r").and_return(@buf)
      allow(JSON).to receive(:parse).and_return([])
      expect(File).to receive(:open).once.ordered.with(<Pathname:myService/myEnv/myService.json>, "w")
      @generator.generate
    end
  end
end
