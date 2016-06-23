require 'spec_helper'

describe ComposeECS do
  context 'while parsing a valid docker-compose definition with volumes' do
    before(:example) do
      test_file = File.open('spec/docker-compose.volumes.yml').read
      @compose = ComposeECS.new('test', test_file)
    end

    it 'parses port definitions in docker-compose format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'app' }['portMappings']).to eq([{ 'hostPort' => 3000, 'containerPort' => 3000, 'protocol' => 'tcp' }, { 'hostPort' => 3000, 'containerPort' => 3000, 'protocol' => 'udp' }])
    end

    it 'parses an environment definiton in docker-compose key-value format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'app' }['environment']).to eq([{ 'name' => 'REDIS_URL', 'value' => 'redis://redis:6379/0' }, { 'name' => 'DB_URL', 'value' => 'db:3306' }])
    end

    it 'parses a command in docker-compose string format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'app' }['command']).to eq('testapp -v debug')
    end

    it 'parses a command in docker-compose array format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'redis' }['command']).to eq(['redis-server', '-p', '6379'])
    end

    it 'parses links definition in docker-compose strict format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'app' }['links']).to eq(['db:db', 'redis:redis'])
    end

    it 'parses mem_limit in docker-compose string format with g & m suffixes' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'db' }['memory']).to eq(1024)
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'app' }['memory']).to eq(2048)
    end

    it 'parses volumes in docker-compose format' do
      expect(JSON.parse(@compose.volumes)).to eq([{ 'name' => 'test-volume-0', 'host' => { 'sourcePath' => '/home/mysql' } }])
    end

    it 'parses logging driver config in docker-compose format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'app' }['logConfiguration'])
      .to eq( 'logDriver' => 'fluentd', 'options' => { 'fluentd-address' => 'localhost:24224' } )
    end

    it 'parses logging driver config in docker-compose v1 format' do
      expect(@compose.to_hash.first['containerDefinitions'].find { |c| c['name'] == 'db' }['logConfiguration'])
      .to eq( 'logDriver' => 'fluentd', 'options' => { 'fluentd-address' => 'localhost:24224' } )
    end

    it 'does not duplicate ECS volume definitions if multiple container volumes reference the same ECS volume' do
      expect(JSON.parse(@compose.volumes).size).to eq(1)
    end

    it 'should produce valid JSON where expected' do
      expect(JSON.parse(@compose.to_s).class).to equal(Hash)
      expect(JSON.parse(@compose.volumes).class).to equal(Array)
      expect(JSON.parse(@compose.no_volumes).class).to equal(Hash)
    end

    it 'should not return volumes from the no_volumes method' do
      expect(JSON.parse(@compose.no_volumes)['volumes']).to be_nil
    end

    it 'should only return volumes array from the volumes method' do
      expect(JSON.parse(@compose.volumes).size).to eq(1)
      expect(JSON.parse(@compose.volumes).class).to equal(Array)
    end

    it 'should not set readOnly to true on a mount point' do
      expect(@compose.to_hash.first['containerDefinitions']
      .find { |c| c['name'] == 'db' }['mountPoints']
      .find { |m| m['containerPath'] == '/var/lib/mysql' }).to_not have_key('readOnly')
    end

    it 'should set readOnly to true on a mount point if specified' do
      expect(@compose.to_hash.first['containerDefinitions']
      .find { |c| c['name'] == 'db' }['mountPoints']
      .find { |m| m['containerPath'] == '/var/lib/db' }['readOnly']).to be true
    end


  end

  context 'while parsing a valid docker-compose definition without volumes' do
    before(:example) do
      test_file = File.open('spec/docker-compose.novolumes.yml').read
      @compose = ComposeECS.new('test', test_file)
    end

    it 'does not produce a volumes key if none are present in the template' do
      expect(JSON.parse(@compose.no_volumes)['volumes']).to be_nil
    end
  end

  context 'while parsing a docker-compose definition without mem_limits' do
    it 'raises an exception if mem_limit is not defined when parsing a defintion' do
      test_file = File.open('spec/docker-compose.invalidmem.yml').read
      expect { ComposeECS.new('test', test_file) }.to raise_error(RuntimeError)
    end
  end

  context 'while parsing a docker-compose definition without an image' do
    it 'raises an exception if image is not defined' do
      test_file = File.open('spec/docker-compose.invalidimage.yml').read
      expect { ComposeECS.new('test', test_file) }.to raise_error(RuntimeError)
    end
  end
end
