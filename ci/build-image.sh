#!/bin/sh
# Builds the shared CI image and (with --push) pushes it.
#
#   ci/build-image.sh registry.example.org/owner/prolog-utilities-ci:latest [--push]
#
# The image name must be the same as the CI_IMAGE repository variable that the
# workflows use. Log in to the registry first (docker login) when pushing.
set -eu
cd "$(dirname "$0")/.."

image=${1:?usage: ci/build-image.sh IMAGE [--push]}

ACT="--load"
if [ "${2:-}" = "--push" ]; then
    ACT="--push"
fi
docker buildx build --platform linux/amd64,linux/arm64 -t "$image" -f .forgejo/images/ci/Dockerfile .forgejo/images/ci ${ACT}
