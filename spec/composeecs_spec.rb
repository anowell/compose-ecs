require 'spec_helper'

describe ComposeECS do

  context "while parsing a valid docker-compose definition with volumes" do
    before(:example) do
      test_file = File.open("spec/docker-compose.volumes.yml").read
      @compose = ComposeECS::ComposeECS.new('test',test_file)
    end

    it "parses port definitions in docker-compose format" do
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "app"}.first["portMappings"]).to eq([{"hostPort"=>3000, "containerPort"=>3000}])
    end

    it "parses an environment definiton in docker-compose key-value format" do
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "app"}.first["environment"]).to eq([{"name"=>"REDIS_URL", "value"=>"redis://redis:6379/0"},{"name"=>"DB_URL", "value"=>"db:3306"}])
    end

    it "parses a command in docker-compose string format" do
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "app"}.first["command"]).to eq("testapp -v debug")
    end

    it "parses a command in docker-compose array format" do
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "redis"}.first["command"]).to eq(["redis-server", "-p", "6379"])
    end

    it "parses links definition in docker-compose strict format" do
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "app"}.first["links"]).to eq(["db:db", "redis:redis"])
    end

    it "parses mem_limit in docker-compose string format with g & m suffixes" do
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "db"}.first["memory"]).to eq(1024)
      expect(@compose.to_hash.first["containerDefinitions"].select{|c| c["name"] == "app"}.first["memory"]).to eq(2048)
    end

    it "parses volumes in docker-compose format" do
      expect(JSON.parse(@compose.volumes)["volumes"]).to eq([{"name"=>"test-volume-0", "host"=>{"sourcePath"=>"/home/mysql"}}])
    end

    it "does not duplicate ECS volume definitions if multiple container volumes reference the same ECS volume" do
      expect(JSON.parse(@compose.volumes)["volumes"].size).to eq(1)
    end

    it "should produce valid JSON where expected" do
      expect(JSON.parse(@compose.to_s).class).to equal(Hash)
      expect(JSON.parse(@compose.volumes).class).to equal(Hash)
      expect(JSON.parse(@compose.no_volumes).class).to equal(Hash)
    end

    it "should not return volumes from the no_volumes method" do
      expect(JSON.parse(@compose.no_volumes)["volumes"]).to be_nil
    end

    it "should only return volumes from the volumes method" do
      expect(JSON.parse(@compose.volumes).keys.first).to eq("volumes")
      expect(JSON.parse(@compose.volumes).keys.size).to eq(1)
    end
  end

  context "while parsing a valid docker-compose definition without volumes" do
    before(:example) do
      test_file = File.open("spec/docker-compose.novolumes.yml").read
      @compose = ComposeECS.new('test',test_file)
    end

    it "does not produce a volumes key if none are present in the template" do
      expect(JSON.parse(@compose.no_volumes)["volumes"]).to be_nil
    end
  end

  context "while parsing a docker-compose definition without mem_limits" do
    it "raises an exception if mem_limit is not defined when parsing a defintion" do
      test_file = File.open("spec/docker-compose.invalidmem.yml").read
      expect{ComposeECS.new('test',test_file)}.to raise_error(RuntimeError)
    end
  end

  context "while parsing a docker-compose definition without an image" do
    it "raises an exception if image is not defined" do
      test_file = File.open("spec/docker-compose.invalidimage.yml").read
      expect{ComposeECS.new('test',test_file)}.to raise_error(RuntimeError)
    end
  end
end
