# compose-ecs [![Build Status](https://travis-ci.com/spaceapegames/compose-ecs.svg?token=PLVFspnXYyAs4yV7xzCM&branch=master)](https://travis-ci.com/spaceapegames/compose-ecs)
Convert Docker Compose files into AWS ECS Task Definitions


## ComposeECS
You can use the ComposeECS object to convert Docker Compose definitions to ECS Task definitions like so:
```ruby
require 'compose-ecs'

# Create a new ComposeECS object by specifying the task family and passing in the Docker Compose string.
c = ComposeECS.new(family, compose_string)

# The Task Definition can then be extracted as a hash...
full_task_definition_hash = c.to_hash
# ... a JSON object...
full_task_definition_json_object = c.to_json
# ... or a pretty JSON string.
full_task_definition_as_string = c.to_s
```

You must ensure that your Docker Compose definiton specifies `image` and `mem_limit` as both are required by ECS.

ComposeECS currently only supports the key-value syntax for environment variables.
## CLI
The CLI tool allows you to convert Docker Compose definitions to ECS Task definitions as part of a shell operation:

`ecs-compose convert <task_family> <compose_file_path>`

This will return the text of the full ECS Task Definition - volumes and family attribute included.

## Supported Docker Compose Features

| Docker Compose Attribute | Task Definition Attribute | Supported Syntax  | Example                                                      |
|--------------------------|---------------------------|-------------------|--------------------------------------------------------------|
| image                    | image                     | String            | "redis"                                                      |
| hostname                 | hostname                  | String            | "myHost"                                                     |
| mem_limit                | memory                    | String            | "100m" or "10g"                                              |
| command                  | command                   | String or Array   | "redis-server -p 6379" or ["redis-server", "-p"..]           |
| ports                    | portMappings              | YAML Array[String]| "8080:8080", "8080:8080/udp", "8080"                         |
| labels                   | dockerLabels              | YAML KV[String]   | MYLBL: "ALBL" (Note: ECS does not allow _'s in the key)      |
| dns                      | dnsServers                | YAML Array[String]| "127.0.0.1"                                                  |
| volumes_from             | volumesFrom               | String            | "myContainer"                                                |
| environment              | environment               | YAML KV[String]   | MYVAR: "AVAR" (Note: ECS does not allow _'s in the key)      |
| links                    | links                     | YAML Array[String]| "myContainer"                                                |
