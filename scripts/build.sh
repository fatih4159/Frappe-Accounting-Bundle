#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
[[ -f .env ]] || { echo 'Zuerst .env.example nach .env kopieren.' >&2; exit 1; }
# .env ist Docker-Compose-Syntax und wird absichtlich nicht als Shellcode geladen.
read_env() { docker compose --profile setup config --environment | sed -n "s/^$1=//p"; }
image="$(read_env CUSTOM_IMAGE)"
tag="$(read_env CUSTOM_TAG)"
ref="$(read_env FRAPPE_DOCKER_REF)"
branch="$(read_env FRAPPE_BRANCH)"
[[ "$ref" =~ ^[0-9a-f]{40}$ ]] || { echo 'FRAPPE_DOCKER_REF muss eine Commit-SHA sein.' >&2; exit 1; }
context="$(mktemp -d)"
trap 'rm -rf "$context"' EXIT
git -C "$context" init -q
git -C "$context" remote add origin https://github.com/frappe/frappe_docker.git
git -C "$context" fetch --depth 1 origin "$ref"
git -C "$context" checkout -q --detach FETCH_HEAD
cp "$context/images/custom/Containerfile" "$context/Containerfile.stack"
cat >> "$context/Containerfile.stack" <<'DOCKERFILE'

USER root
RUN apt-get update && apt-get install --no-install-recommends -y ffmpeg \
    && rm -rf /var/lib/apt/lists/*
USER frappe
DOCKERFILE
cache_bust="$(sha256sum apps.json | cut -d ' ' -f 1)"
docker build --pull --build-arg "FRAPPE_BRANCH=$branch" \
  --build-arg PYTHON_VERSION=3.14 --build-arg NODE_VERSION=24 \
  --build-arg "CACHE_BUST=$cache_bust" \
  --secret "id=apps_json,src=$PWD/apps.json" \
  --tag "$image:$tag" --file "$context/Containerfile.stack" "$context"
