function load_environment {
    source /var/lib/jenkins/.rvm/environments/ruby-2.1.5
    if [ ! -f config/application.yml ]; then
        ln -s application.yml.example config/application.yml
    fi
}

function require_env_vars {
    for var in "$@"; do
      eval value=\$$var
      echo "$var=$value"
      if [ -z "$value" ]; then
          echo "Environment variable $var missing."
          exit 1
      fi
    done
}

function master_merged {
    git branch -r --merged HEAD | grep -Fxq '  origin/master'
}

function exit_unless_merged_into_master {
  if ! [ `git merge-base HEAD origin/master` = $OFN_COMMIT ]; then
    echo "This branch is not yet merged into master. Please merge in GitHub first."
    exit 1
  fi
}

function exit_unless_master_merged {
    if ! master_merged; then
	echo "This branch does not have the current master merged. Please merge master and push again."
	exit 1
    fi
}

function succeed_if_master_merged {
    if master_merged; then
        exit 0
    fi
}

function set_ofn_commit {
    echo "Setting commit to $1"
    buildkite-agent meta-data set "openfoodnetwork:git:commit" $1
}

function get_ofn_commit {
    OFN_COMMIT=`buildkite-agent meta-data get "openfoodnetwork:git:commit"`

    # If we don't catch this failure case, push will execute:
    # git push remote :master --force
    # Which will delete the master branch on the server

    if [[ `expr length "$OFN_COMMIT"` == 0 ]]; then
        echo 'OFN_COMMIT_NOT_FOUND'
    else
        echo $OFN_COMMIT
    fi
}

function checkout_ofn_commit {
    OFN_COMMIT=`buildkite-agent meta-data get "openfoodnetwork:git:commit"`
    echo "Checking out stored commit $OFN_COMMIT"
    git checkout -qf "$OFN_COMMIT"
}

function drop_and_recreate_database {
    # Adapted from: http://stackoverflow.com/questions/12924466/capistrano-with-postgresql-error-database-is-being-accessed-by-other-users
    DB=$1
    shift
    psql postgres $@ <<EOF
REVOKE CONNECT ON DATABASE $DB FROM public;
ALTER DATABASE $DB CONNECTION LIMIT 0;
SELECT pg_terminate_backend(procpid)
FROM pg_stat_activity
WHERE procpid <> pg_backend_pid()
AND datname='$DB';
DROP DATABASE $DB;
CREATE DATABASE $DB;
EOF
}

function github_status {
  github_repo="$(echo $BUILDKITE_REPO | sed 's/git@github.com:\(.*\).git/\1/')"
  commit="$(git rev-parse HEAD)"
  github_api_url="https://api.github.com/repos/$github_repo/commits/$commit/status"
  curl -s "$github_api_url" | grep '^  "state":' | grep 'failure\|pending\|success' -o
}
