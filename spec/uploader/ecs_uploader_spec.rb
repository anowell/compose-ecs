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

describe Spaceape::Cloudformation::EcsUploader do
  before do
    %x[mkdir -p ecs/myService && mkdir policies; echo '{}' > ecs/myService/myService.json; echo '{}' > policies/ecs-locked.json; echo '{}' > policies/unlock-all.json ]
    @uploader = Spaceape::Cloudformation::EcsUploader.new("ecs", "myService")
  end

  after(:each) do
    %x[rm -rf ecs policies]
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
    it "should register a new task definition by default" do
      @cf = MockAWS::Cloudformation.new
      @regex = "arn:aws:ecs:.*:.*:task-definition/myService:[0-9]+"
      expect(@uploader).to receive(:get_latest_revision).at_least(1).times.and_return("taskdef:21")
      expect(@uploader).to receive(:update_taskdef_in_template).with("taskdef:21").and_return(true)
      expect(@uploader).to receive(:shell_out).ordered.with("aws ecs register-task-definition --cli-input-json file://ecs/myService/task-definition.json").and_return(true)
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:create_stack)
      @uploader.create_stack
    end

    it "should create the stack with the specified version of the task-definition" do
      @cf = MockAWS::Cloudformation.new
      @regex = "arn:aws:ecs:.*:.*:task-definition/myService:[0-9]+"
      expect(@uploader).to receive(:get_specific_revision).and_return("taskdef:21")
      expect(@uploader).to receive(:shell_out).ordered.with("sed -E -i '' -e \'s|#{@regex}|taskdef:21|\' ecs/myService/myService.json").and_return(true)
      expect(@uploader).to receive(:shell_out).ordered.with("sed -i '' -e \'s|__TASKDEF__|taskdef:21|\' ecs/myService/myService.json").and_return(true)
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:create_stack)
      @uploader.create_stack({:revision => "21"})
    end

    it "should not update the task-definition if --no-taskdef is passed" do
       @cf = MockAWS::Cloudformation.new
      @regex = "arn:aws:ecs:.*:.*:task-definition/myService:[0-9]+"
      expect(@uploader).to receive(:get_latest_revision).and_return("taskdef:21")
      expect(@uploader).to receive(:update_taskdef_in_template).with("taskdef:21").and_return(true)
      expect(@uploader).to_not receive(:shell_out).ordered.with("aws ecs register-task-definition --cli-input-json file://ecs/myService/task-definition.json")
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:create_stack)
      @uploader.create_stack({:no_taskdef => true})   
    end
  end

  describe 'update_stack' do
    it "should only update the task definition if the taskdef_only flag is passed" do 
      expect(@uploader).to receive(:update_task_definition).and_return(true)
      expect(@uploader).to_not receive(:update_taskdef_in_template)
      @uploader.update_stack({:taskdef_only => true})
    end

    it "should update the stack with the specified version of the task-definition" do
      @cf = MockAWS::Cloudformation.new
      @regex = "arn:aws:ecs:.*:.*:task-definition/myService:[0-9]+"
      expect(@uploader).to receive(:get_specific_revision).and_return("taskdef:21")
      expect(@uploader).to receive(:shell_out).ordered.with("sed -E -i '' -e \'s|#{@regex}|taskdef:21|\' ecs/myService/myService.json").and_return(true)
      expect(@uploader).to receive(:shell_out).ordered.with("sed -i '' -e \'s|__TASKDEF__|taskdef:21|\' ecs/myService/myService.json").and_return(true)
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:update_stack)
      @uploader.update_stack({:revision => "21"})
    end
  end

end
