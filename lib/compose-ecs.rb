require 'yaml'
require 'json'

class ECSDefinition
  attr_accessor :container_definitions, :volume_definitions

  def initialize(family)
    @container_definitions = []
    @volume_definitions = []
    @family = family
  end

  def build
    output = { 'family' => @family, 'containerDefinitions' => [] }
    @container_definitions.each do |container|
      output['containerDefinitions'] << container.definition
    end

    generated_volumes = []

    @volume_definitions.each do |volume|
      # Check if ECS volume exists for mount point, create one if not and remember the name if it does
      lookup = generated_volumes.find { |v| v['host']['sourcePath'] == volume.source }

      if lookup.nil?
        new_volume = generate_volume(volume.source, generated_volumes.size)

        generated_volumes << new_volume
        volume_name = new_volume['name']
      else
        volume_name = lookup['name']
      end

      # Map the ECS volume to the mount point in the container definition
      mount_point = { 'sourceVolume' => volume_name, 'containerPath' => volume.mount }
      mount_point['readOnly'] = true if volume.ro?

      if output['containerDefinitions'].find { |c| c['name'] == volume.container }.keys.include? 'mountPoints'
        output['containerDefinitions'].find { |c| c['name'] == volume.container }['mountPoints'] << mount_point
      else
        output['containerDefinitions'].find { |c| c['name'] == volume.container }['mountPoints'] = [ mount_point ]
      end
    end

    output['volumes'] = generated_volumes unless generated_volumes.empty?

    [output]
  end

  def generate_volume(source, size)
    { 'name' => "#{@family}-volume-#{size}", 'host' => { 'sourcePath' => source } }
  end
end

class ECSContainerDefinition
  attr_accessor :definition

  def initialize(container)
    @definition = { 'name' => container }
  end

  def compose_ports(port_map)
    return if port_map.nil?

    ecs_mapping = []

    port_map = port_map.map { |pm| pm.split(':') unless pm.nil? }

    port_map.each do |mapping|
      protocol = 'tcp'
      if mapping[mapping.size - 1].include?('/udp')
        mapping[mapping.size - 1] = mapping[mapping.size - 1].split('/').first
        protocol = 'udp'
      end

      case mapping.size
      when 1
        ecs_mapping << { 'containerPort' => mapping[0].to_i, 'protocol' => protocol }
      when 2
        ecs_mapping << { 'hostPort' => mapping[0].to_i, 'containerPort' => mapping[1].to_i, 'protocol' => protocol }
      else
        fail "Invalid port mapping: #{mapping}"
      end
    end

    @definition['portMappings'] = ecs_mapping
  end

  def compose_environment(environment_map)
    return if environment_map.nil?

    ecs_environment = []

    environment_map.each_pair do |k, v|
      ecs_environment << { 'name' => k, 'value' => v.to_s }
    end

    @definition['environment'] = ecs_environment
  end

  def compose_hostname(hostname)
    return if hostname.nil?
    fail 'hostname must be of type String' if hostname.class != String

    @definition['hostname'] = hostname
  end

  def compose_labels(labels)
    return if labels.nil?
    fail 'Labels must be of type Hash' if labels.class != Hash
    fail 'Label values must be of type String' unless labels.values.select { |v| v.class != String }.empty?
    fail 'Label values must be of type String' unless labels.keys.select { |v| v.class != String }.empty?

    @definition['dockerLabels'] = labels
  end

  def compose_privileged(privileged)
    return if privileged.nil?
    fail "privileged must be boolean" unless privileged.instance_of? TrueClass or privileged.instance_of? FalseClass

    @definition['privileged'] = privileged
  end

  def compose_dns(dns)
    return if dns.nil?
    fail 'dns must be of type Array' if dns.class != Array

    @definition['dnsServers'] = dns
  end

  def compose_volumesfrom(containers)
    return if containers.nil?
    fail 'volumes_from must be of type Array' if containers.class != Array

    @definition['volumesFrom'] = containers.map { |c| { 'sourceContainer' => c } }
  end

  def compose_command(command)
    return if command.nil?

    if command.class == Array || command.class == String
      @definition['command'] = command
    else
      fail 'Command must be of type Array or String'
    end
  end

  def compose_memory(memory)
    fail "You must define a mem_limit for container: #{@definition['name']}" if memory.nil?
    fail "mem_limit must be of type String. Value provided is of type #{memory.class}" if memory.class != String

    unit = memory[-1]
    value = memory[0..-2].to_i # Remove the unit

    case unit
    when 'm'
      @definition['memory'] = value
    when 'g'
      @definition['memory'] = value * 1024
    else
      fail 'Unsupported memory unit. Supported values: m(MB), g(GB)'
    end
  end

  def compose_links(link_map)
    return if link_map.nil?

    @definition['links'] = link_map
  end

  def compose_image(image)
    fail "You must define an image for container: #{@definition['name']}" if image.nil?

    @definition['image'] = image
  end

  def compose_logging(logging)
    return if logging.nil?
    @definition['logConfiguration'] = {}.tap do |l|
      l['logDriver'] = logging.fetch('driver') { fail "Missing logging driver." }
      l['options'] = logging['options']
    end
  end

  def compose_logging_v1(log_driver, log_opts)
    if log_driver.nil?
      fail "log_opts makes no sense without log_driver" unless log_opts.nil?
      return
    end

    compose_logging({ 'driver' => log_driver,
                      'options' => log_opts || {}}) 
    
  end
end

class ECSVolumeDefinition
  attr_accessor :source, :mount, :container, :mode

  def initialize(volume_string, container)
    volume_arr = volume_string.split(':')
    if volume_arr.last =~ /r[o,w]/
      @mode = volume_arr.pop
    end

    case volume_arr.size
    when 1
      @source = volume_arr[0]
      @mount = volume_arr[0]
    when 2
      @source = volume_arr[0]
      @mount = volume_arr[1]
    else
      fail "Invalid volume definition: #{volume_string}"
    end

    @container = container
  end

  def ro?
    @mode == "ro"
  end
end

class ComposeECS
  attr_accessor :output

  def initialize(family, compose_string)
    yaml = YAML.load(compose_string)
    ecs_def = ECSDefinition.new(family)

    yaml.keys.each do |container|
      container_data = yaml[container]
      ecs_container_def = ECSContainerDefinition.new(container)

      # Translation methods
      ecs_container_def.compose_ports(container_data['ports'])
      ecs_container_def.compose_image(container_data['image'])
      ecs_container_def.compose_memory(container_data['mem_limit'])
      ecs_container_def.compose_command(container_data['command'])
      ecs_container_def.compose_hostname(container_data['hostname'])
      ecs_container_def.compose_labels(container_data['labels'])
      ecs_container_def.compose_dns(container_data['dns'])
      ecs_container_def.compose_volumesfrom(container_data['volumes_from'])
      ecs_container_def.compose_environment(container_data['environment'])
      ecs_container_def.compose_links(container_data['links'])
      ecs_container_def.compose_privileged(container_data['privileged'])
      ecs_container_def.compose_logging(container_data['logging'])
      # Support Version 1 docker-compose files:
      ecs_container_def.compose_logging_v1(container_data['log_driver'], container_data['log_opt'])

      ecs_def.container_definitions << ecs_container_def

      unless container_data['volumes'].nil?
        container_data['volumes'].each do |volume|
          ecs_def.volume_definitions << ECSVolumeDefinition.new(volume, container)
        end
      end
    end
    @output = ecs_def.build
  end

  def no_volumes
    JSON.pretty_generate('family' => @output[0]['family'], 'containerDefinitions' => @output[0]['containerDefinitions'])
  end

  def volumes
    if @output[0].keys.include? 'volumes'
      return JSON.pretty_generate(@output[0]['volumes'])
    else
      return ''
    end
  end

  def to_s
    JSON.pretty_generate(@output[0])
  end

  def to_json
    @output.to_json
  end

  def to_hash
    @output
  end
end
