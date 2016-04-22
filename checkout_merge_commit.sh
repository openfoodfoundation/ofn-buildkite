#!/bin/bash

set -exo pipefail
source "$(dirname $0)/includes.sh"

# This is the commit tested by Travis
git fetch origin "pull/$BUILDKITE_PULL_REQUEST/merge"
git checkout FETCH_HEAD
