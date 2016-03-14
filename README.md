# compose-ecs
Convert Docker Compose files into AWS ECS Task Definitions

[![Build Status](https://travis-ci.com/spaceapegames/compose-ecs.svg?token=PLVFspnXYyAs4yV7xzCM&branch=master)](https://travis-ci.com/spaceapegames/compose-ecs)

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
