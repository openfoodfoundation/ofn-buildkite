#!/bin/bash

set -exo pipefail
source "`dirname $0`/includes.sh"

test "$(github_status)" = "success"

if ! master_merged; then
    git merge origin/master --no-edit
    if [ -n "$BUILDKITE_PULL_REQUEST" ]; then
        git push --force origin "HEAD:refs/heads/merged-pull/$BUILDKITE_PULL_REQUEST"
    else
        git push origin "HEAD:$BUILDKITE_BRANCH"
    fi
    buildkite-agent meta-data set "buildkite:git:commit" "`git show HEAD -s --format=fuller --no-color`"
fi

set_ofn_commit "$(git rev-parse HEAD)"

STAGING_REMOTE="${STAGING_REMOTE:-$STAGING_SSH_HOST:$STAGING_CURRENT_PATH}"

echo "--- Checking environment variables"
require_env_vars STAGING_SSH_HOST STAGING_CURRENT_PATH STAGING_REMOTE STAGING_SERVICE STAGING_DB_HOST STAGING_DB_USER STAGING_DB

# TODO: Optimise staging deployment
# This is stopping and re-starting unicorn and delayed job.
echo "--- Loading baseline data"
VARS="CURRENT_PATH='$STAGING_CURRENT_PATH' SERVICE='$STAGING_SERVICE' DB_HOST='$STAGING_DB_HOST' DB_USER='$STAGING_DB_USER' DB='$STAGING_DB'"
ssh "$STAGING_SSH_HOST" "$VARS $STAGING_CURRENT_PATH/script/ci/load_staging_baseline.sh"

# This is stopping and re-starting unicorn and delayed job again.
echo "--- Pushing to staging"
exec 5>&1
OUTPUT="$(git push "$STAGING_REMOTE" HEAD:master --force 2>&1 |tee /dev/fd/5)"
[[ $OUTPUT =~ "Done" ]]
