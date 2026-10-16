Copyright (c) 2026, mnheia

# docker-tools
Small Bash utilities for Docker maintenance and cleanup.

## docker-cleanup.sh
Performs conservative Docker housekeeping without deleting volumes or indiscriminately pruning all unused images.

By default it:

- removes stopped containers older than 7 days
- removes dangling images older than 14 days
- removes unused networks
- removes build cache older than 14 days
- removes specially tagged rollback images older than 30 days
- shows Docker disk usage before and after cleanup
- lists running containers when finished

Rollback images are detected using tags in this format:

```text
repository:rollback-YYYYMMDD_HHMMSS
```

Example:

```text
myapp:rollback-20260915_143012
```

## Configuration
Retention periods can be overridden with environment variables:

- `STOPPED_CONTAINER_RETENTION_DAYS`
- `DANGLING_IMAGE_RETENTION_DAYS`
- `ROLLBACK_IMAGE_RETENTION_DAYS`
- `BUILD_CACHE_RETENTION_DAYS`
- `LOCK`
- `LOG`

Example:

```bash
ROLLBACK_IMAGE_RETENTION_DAYS=60 \
BUILD_CACHE_RETENTION_DAYS=7 \
./docker-cleanup.sh
```

## Safety
The script does not run `docker system prune -a` and does not delete Docker volumes.

It only removes dangling images through Docker's normal prune operation. Tagged images are removed only when their tag explicitly matches the `rollback-YYYYMMDD_HHMMSS` convention and is older than the configured retention period.

## Requirements
- Bash
- Docker CLI with access to the Docker daemon
- GNU `date`
- `flock`
- standard GNU/Linux utilities

## Bugs
Please report bugs or feature requests through the web interface at https://github.com/mnheia/docker-tools/issues
