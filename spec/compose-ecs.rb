require 'rspec'
require 'compose-ecs'



RSpec.describe ComposeECS do



  context "while parsing a valid docker-compose definition with volumes" do
    before(:example) do
      test_file = File.open("docker-compose.volumes.yml").read
      @compose = ComposeECS.new('test',test_file)
    end

    it "parses port definitions in docker-compose format" do

    end

    it "parses an environment definiton in docker-compose key-value format" do

    end

    it "parses a command in docker-compose string format" do

    end

    it "parses mem_limit in docker-compose string format" do

    end

    it "parses links definition in docker-compose strict format" do

    end

    it "parses mem_limit in docker-compose string format" do

    end

    it "parses volumes in docker-compose format" do

    end

    it "does not duplicate ECS volume definitions if multiple container volumes reference the same ECS volume" do

    end

    it "should produce valid JSON where expected" do

    end

    it "should not return volumes from the no_volumes method" do

    end

    it "should only return volumes from the volumes method" do

    end
  end

  context "while parsing a valid docker-compose definition without volumes" do
    before(:example) do
      test_file = File.open("docker-compose.novolumes.yml").read
      @compose = ComposeECS.new('test',test_file)
    end

    it "does not produce a volumes key if none are present in the template" do

    end
  end

  context "while parsing a docker-compose definition without mem_limits" do
    before(:example) do
      test_file = File.open("docker-compose.invalidmem.yml").read
      @compose = ComposeECS.new('test',test_file)
    end

    it "raises an exception if mem_limit is not defined when parsing a defintion" do

    end
  end

  context "while parsing a docker-compose definition without an image" do
    before(:example) do
      test_file = File.open("docker-compose.invalidimage.yml").read
      @compose = ComposeECS.new('test',test_file)
    end

    it "raises an exception if image is not defined" do

    end
  end
end
