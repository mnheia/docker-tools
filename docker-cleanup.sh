#!/usr/bin/env bash
# Author: mnheia
# Copyright (c) 2026 mnheia
# Repository: https://github.com/mnheia/docker-tools
# License: GPL-3.0 (see LICENSE)

set -Eeuo pipefail

LOCK="${LOCK:-/run/lock/docker-cleanup.lock}"
LOG="${LOG:-/var/log/docker-cleanup.log}"

STOPPED_CONTAINER_RETENTION_DAYS="${STOPPED_CONTAINER_RETENTION_DAYS:-7}"
DANGLING_IMAGE_RETENTION_DAYS="${DANGLING_IMAGE_RETENTION_DAYS:-14}"
ROLLBACK_IMAGE_RETENTION_DAYS="${ROLLBACK_IMAGE_RETENTION_DAYS:-30}"
BUILD_CACHE_RETENTION_DAYS="${BUILD_CACHE_RETENTION_DAYS:-14}"

exec >>"$LOG" 2>&1

echo
echo "===== $(date -Is) starting Docker cleanup ====="

exec 200>"$LOCK"
flock -n 200 || {
  echo "Another Docker cleanup is already running. Exiting."
  exit 0
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

for cmd in docker date grep flock; do
  need_cmd "$cmd"
done

if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker daemon is not reachable." >&2
  exit 1
fi

days_to_hours() {
  echo "$(($1 * 24))h"
}

echo
echo "Docker disk usage before cleanup:"
docker system df || true

echo
echo "Removing stopped containers older than ${STOPPED_CONTAINER_RETENTION_DAYS} days"
docker container prune -f \
  --filter "until=$(days_to_hours "$STOPPED_CONTAINER_RETENTION_DAYS")" || true

echo
echo "Removing dangling images older than ${DANGLING_IMAGE_RETENTION_DAYS} days"
docker image prune -f \
  --filter "dangling=true" \
  --filter "until=$(days_to_hours "$DANGLING_IMAGE_RETENTION_DAYS")" || true

echo
echo "Removing unused Docker networks"
docker network prune -f || true

echo
echo "Removing Docker build cache older than ${BUILD_CACHE_RETENTION_DAYS} days"
docker builder prune -f \
  --filter "until=$(days_to_hours "$BUILD_CACHE_RETENTION_DAYS")" || true

echo
echo "Removing rollback image tags older than ${ROLLBACK_IMAGE_RETENTION_DAYS} days"

cutoff_epoch="$(date -d "${ROLLBACK_IMAGE_RETENTION_DAYS} days ago" +%s)"

while IFS= read -r image_ref; do
  [ -n "$image_ref" ] || continue

  tag="${image_ref##*:}"
  stamp="${tag#rollback-}"

  year="${stamp:0:4}"
  month="${stamp:4:2}"
  day="${stamp:6:2}"
  hour="${stamp:9:2}"
  minute="${stamp:11:2}"
  second="${stamp:13:2}"

  image_epoch="$(date -d "${year}-${month}-${day} ${hour}:${minute}:${second}" +%s 2>/dev/null || echo 0)"

  if [ "$image_epoch" -gt 0 ] && [ "$image_epoch" -lt "$cutoff_epoch" ]; then
    echo "Removing old rollback image tag: $image_ref"
    docker image rm "$image_ref" || true
  else
    echo "Keeping rollback image tag: $image_ref"
  fi
done < <(
  docker image ls --format '{{.Repository}}:{{.Tag}}' \
    | grep -E ':rollback-[0-9]{8}_[0-9]{6}$' || true
)

echo
echo "Docker disk usage after cleanup:"
docker system df || true

echo
echo "Running containers:"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}' || true

echo
echo "Docker cleanup completed successfully"
echo "===== $(date -Is) finished Docker cleanup ====="
