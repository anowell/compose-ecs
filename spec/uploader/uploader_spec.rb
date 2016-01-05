require 'spec_helper'

class MockAWS 
  class Cloudformation 
    def create_stack(opts) 
      return true 
    end

    def update_stack(opts)
      return true
    end
  end
end

include Spaceape::AWS

describe Spaceape::Cloudformation::Uploader do
  before do
    %x[mkdir -p myService/myEnv && mkdir policies; echo '{}' > myService/myEnv/myService.json; echo '{}' > policies/locked.json; echo '{}' > policies/unlock-all.json ]
    @uploader = Spaceape::Cloudformation::Uploader.new("myService", "myEnv")
  end

  after(:each) do
    %x[rm -rf myService policies]
  end

  describe 'initialize' do
    it "should initialize itself with default region and AWS config" do
      @uploader.region.equal?("us-east-1")      
      @uploader.aws_config.equal?("~/.aws/config")
    end

    it 'should initialize itself with a different region if provided' do
      @uploader = Spaceape::Cloudformation::EcsGenerator.new("ecs", "myService", "myRegion")
      @uploader.region.equal?("myRegion")
    end
  end

  describe 'create_stack' do
    it "should create a new stack with the correct policy" do
      @cf = MockAWS::Cloudformation.new
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:create_stack).with({:stack_name=>nil, :template_body=>"{}\n", :capabilities=>["CAPABILITY_IAM"], :stack_policy_body=>"{ \"TEST\" : 1 }\n", :disable_rollback=>true})
      @uploader.create_stack({:policy => File.expand_path('../../mock_skels/myPolicy.json', __FILE__)})
    end
  end

  describe 'update_stack' do
    it "should update a stack with the correct policy" do
      @cf = MockAWS::Cloudformation.new
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:update_stack).with({:stack_name=>nil, :template_body=>"{}\n", :capabilities=>["CAPABILITY_IAM"], :stack_policy_during_update_body=>"{ \"TEST\" : 1 }\n"})
      @uploader.update_stack({:policy => File.expand_path('../../mock_skels/myPolicy.json', __FILE__)})
    end
  end

end
