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
    output = {"family" => @family, "containerDefinitions" => []}

    @container_definitions.each do |container|
      output["containerDefinitions"] << container.definition
    end

    generated_volumes = []

    @volume_definitions.each do |volume|

      # Check if ECS volume exists for mount point, create one if not and remember the name if it does
      lookup = generated_volumes.select{ |v| v["host"]["sourcePath"] == volume.source}.first

      if lookup.nil?
        new_volume = generate_volume(volume.source, generated_volumes.size)

        generated_volumes << new_volume
        volume_name = new_volume["name"]
      else
        volume_name = lookup["name"]
      end


      # Map the ECS volume to the mount point in the container definition
      if output["containerDefinitions"].select{ |c| c["name"] == volume.container}.first.keys.include? "mountPoints"
        output["containerDefinitions"].select{ |c| c["name"] == volume.container}.first["mountPoints"] << {"sourceVolume" => volume_name,"containerPath" => volume.mount}
      else
        output["containerDefinitions"].select{ |c| c["name"] == volume.container}.first["mountPoints"] = [{"sourceVolume" => volume_name,"containerPath" => volume.mount}]
      end

    end


    output["volumes"] = generated_volumes unless generated_volumes.empty?

    return [output]
  end

  def generate_volume(source, size)
    return {"name" => "#{@family}-volume-#{size}","host" => {"sourcePath" => source }}
  end
end

class ECSContainerDefinition

  attr_accessor :definition

  def initialize(container)
    @definition = {"name" => container}
  end

  def compose_ports(port_map)
    return if port_map.nil?

    ecs_mapping = []

    port_map = port_map.map{ |pm| pm.split(":") if !pm.nil? }

    port_map.each do |mapping|
      case mapping.size
      when 1
        ecs_mapping << { "containerPort" => mapping[0].to_i}
      when 2
        ecs_mapping << { "hostPort" => mapping[0].to_i, "containerPort" => mapping[1].to_i}
      else
        raise "Invalid port mapping: #{mapping}"
      end
    end

    @definition["portMappings"] = ecs_mapping
  end

  def compose_environment(environment_map)
    return if environment_map.nil?

    ecs_environment = []

    environment_map.each_pair do |k,v|
      ecs_environment << { "name" => k, "value" => v.to_s }
    end

    @definition["environment"] = ecs_environment
  end

  def compose_command(command)
    return if command.nil?

    @definition["command"] = command.delete('"').split(" ")
  end

  def compose_memory(memory)
    raise "You must define a mem_limit for container: #{@definition["name"]}" if memory.nil?

    @definition["memory"] = memory
  end

  def compose_links(link_map)
    return if link_map.nil?

    @definition["links"] = link_map
  end

  def compose_image(image)
      raise "You must define an image for container: #{@definition["name"]}" if image.nil?

      @definition["image"] = image
  end
end

class ECSVolumeDefinition

  attr_accessor :source, :mount, :container

  def initialize(volume_string, container)

    volume_arr = volume_string.split(":")

    case volume_arr.size
    when 1
      @source = volume_arr[0]
      @mount = volume_arr[0]
    when 2
      @source = volume_arr[0]
      @mount = volume_arr[1]
    else
      raise "Invalid volume definition: #{volume_string}"
    end

    @container = container
  end
end

class ComposeECS

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
      ecs_container_def.compose_environment(container_data['environment'])
      ecs_container_def.compose_links(container_data['links'])

      ecs_def.container_definitions << ecs_container_def

      unless container_data['volumes'].nil?
        container_data['volumes'].each do |volume|
          ecs_def.volume_definitions << ECSVolumeDefinition.new(volume, container)
        end
      end
    end
    @output = ecs_def.build
  end

  def to_s
    return JSON.pretty_generate(@output[0])
  end

  def to_json
    @output.to_json
  end

  def to_hash
    @output
  end
end
