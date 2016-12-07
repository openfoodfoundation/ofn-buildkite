#!/bin/bash

set -exo pipefail
source "`dirname $0`/includes.sh"

OFN_COMMIT="$(get_ofn_commit)"
git checkout -qf "$OFN_COMMIT"
buildkite-agent meta-data set "buildkite:git:commit" "`git show HEAD -s --format=fuller --no-color`"
buildkite-agent meta-data set "buildkite:git:branch" "`git branch --contains HEAD --no-color`"

test "$(github_status)" = "success"
master_merged

echo "--- Checking environment variables"
require_env_vars OFN_COMMIT STAGING_SSH_HOST STAGING_CURRENT_PATH STAGING_SERVICE STAGING_DB_HOST STAGING_DB_USER STAGING_DB PRODUCTION_REMOTE

echo "--- Saving baseline data for staging"
VARS="CURRENT_PATH='$STAGING_CURRENT_PATH' SERVICE='$STAGING_SERVICE' DB_HOST='$STAGING_DB_HOST' DB_USER='$STAGING_DB_USER' DB='$STAGING_DB'"
ssh "$STAGING_SSH_HOST" "$VARS $STAGING_CURRENT_PATH/script/ci/save_staging_baseline.sh $OFN_COMMIT"

# Only the Australian team is pushing to the global master branch.
# We are the gate keepers for now.
#
# It will trigger Travis to run again so that `github_status` will return
# "pending" instead of "success" for a while. That's why I kept it in one
# script.
if [ "$PUSH_TO_ORIGIN_MASTER" = "true" ]; then
    echo "--- Pushing to origin/master"
    git push origin "$OFN_COMMIT:master"
fi

echo "--- Pushing to production"
exec 5>&1
OUTPUT=$(git push "$PRODUCTION_REMOTE" "$OFN_COMMIT":master --force 2>&1 |tee /dev/fd/5)
[[ $OUTPUT =~ "Done" ]]
