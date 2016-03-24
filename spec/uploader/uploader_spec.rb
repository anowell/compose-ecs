require 'spec_helper'
require 'ostruct'

class MockAWS 
  class Cloudformation 

    def stacks
      { "mystack" =>
      OpenStruct.new(:resources => [ OpenStruct.new(:resource_type => "AWS::AutoScaling::AutoScalingGroup", 
                                                  :physical_resource_id => "my_as_group", 
                                                  :logical_resource_id => "my_logical_resource" 
                                                  ) ]
      )
      }
    end

    def create_stack(opts) 
      return true 
    end

    def update_stack(opts)
      return true
    end
  end

  class AutoScaling
    def groups
      { "my_as_group" => OpenStruct.new(:desired_capacity => 10) }
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
      %x[mkdir myService/myEnv/myRegion && echo {} > myService/myEnv/myRegion/myService.json]
      @uploader = Spaceape::Cloudformation::Uploader.new("myService", "myEnv", "myRegion")
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
      expect(@uploader).to receive(:check_asg_size).with("mystack", "myService/myEnv/myService.json").and_return(true)
      expect(@cf).to receive(:update_stack).with({:stack_name=>"mystack", :template_body=>"{}\n", :capabilities=>["CAPABILITY_IAM"], :stack_policy_during_update_body=>"{ \"TEST\" : 1 }\n"})
      @uploader.update_stack({:stackname => "mystack", :policy => File.expand_path('../../mock_skels/myPolicy.json', __FILE__)})
    end

    it 'should sanity check the ASG size(s)' do
      @tmpl=<<JSON
{
   "AWSTemplateFormatVersion" : "2010-09-09",
   "Resources" : {
      "my_logical_resource" : {
         "Properties" : {
            "MaxSize" : {
               "Ref" : "MaxInstances"
            },
            "MinSize" : {
               "Ref" : "MinInstances"
            }
         }
      }
   },
   "Description" : "testy testy",
   "Parameters" : {
      "MaxInstances" : {
         "Type" : "Number",
         "Default" : 1,
         "Description" : "Maximum instances in AutoScale group"
      }
   }
}
JSON
      File.open('myService/myEnv/myService.json', 'w') {|f| f.write(@tmpl) }
      @cf = MockAWS::Cloudformation.new
      @as = MockAWS::AutoScaling.new
      allow(@uploader).to receive(:setup_amazon).once.ordered.with('AutoScaling', '~/.aws/config', 'us-east-1').and_return(@as)
      allow(@uploader).to receive(:setup_amazon).once.ordered.with('CloudFormation', '~/.aws/config', 'us-east-1').and_return(@cf)
      lambda { @uploader.update_stack({:stackname => "mystack", :policy => File.expand_path('../../mock_skels/myPolicy.json', __FILE__)}) }.should raise_error SystemExit 
    end

    it "should not sanity check the ASG size if :no_asg_check is passed" do
      @cf = MockAWS::Cloudformation.new
      allow_any_instance_of(Spaceape::AWS).to receive(:setup_amazon).with('CloudFormation::Client', '~/.aws/config', 'us-east-1').and_return(@cf)
      expect(@cf).to receive(:update_stack).with({:stack_name=>"mystack", :template_body=>"{}\n", :capabilities=>["CAPABILITY_IAM"], :stack_policy_during_update_body=>"{ \"TEST\" : 1 }\n"})
      @uploader.update_stack({:stackname => "mystack", :policy => File.expand_path('../../mock_skels/myPolicy.json', __FILE__), :no_asg_check => true})
    end
  end

end
