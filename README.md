# Buildkite Continuous Integration scripts for the Open Food Network

The main scripts are `push_to_staging.sh` and `push_to_production.sh`.

## Push to staging server

The `push_to_staging.sh` script does the following:

- Check that the current commit passed all tests (Github status = success).
- If the master branch is not merged:
 - Merge master
 - Push the updated branch to the main repository. In case of pull requests, this creates a new branch `merged-pull/$num`.
- Save the current commit id for later, in case it changed through merging.
- Reset the database on the staging server.
- Push to the staging server (deploy).

## Push to production server

- Checkout the commit saved earlier.
- Check that the current commit passed all tests.
- Check that master is merged, fail otherwise.
- Save the database on the staging server to preserve the current stage.
- Push to main repository. The branch is officially merged now.
- Push to production server (deploy).
