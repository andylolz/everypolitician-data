#!/usr/bin/env bash
#
# This script is very similar to, but not exactly the same as
# `scripts/release.sh` in viewer-sinatra. Any significant changes to this
# script might also need to be made there as well. It may also get to a point
# where we want to combine the scripts into a shared repository, but for now
# they're different enough to keep separate, I think.
#
# @see https://git.io/viyyo

set -eo pipefail

[[ "$TRACE" ]] && set -x

start_viewer_sinatra() {
  mkdir -p /tmp/viewer-sinatra
  cd /tmp/viewer-sinatra
  # TODO: Make `master` configurable
  curl -fsSL https://github.com/everypolitician/viewer-sinatra/archive/master.tar.gz | tar -z -x -f - --strip 1
  unset BUNDLE_GEMFILE
  bundle install
  bundle exec ruby app.rb &
  while ! nc -z localhost 4567; do sleep 1; done
}

build_viewer_static() {
  cd /tmp
  wget -nv -m localhost:4567/status/all_countries.html || (echo "wget exited with non-zero exit code: $?" >&2 && exit 1)
}

deploy_viewer_static() {
  cd /tmp
  git clone --depth=1 https://github.com/everypolitician/viewer-static.git
  cd viewer-static
  git checkout gh-pages
  cp -R /tmp/localhost:4567/* .
  git add .
  git -c "user.name=everypoliticianbot" -c "user.email=everypoliticianbot@users.noreply.github.com" commit -m "Automated commit" || true
  git push origin gh-pages
}

main() {
  if [[ "$TRAVIS_PULL_REQUEST" == false && "$TRAVIS_BRANCH" == master ]]; then
    if [[ -z $(git diff --name-only "$TRAVIS_COMMIT_RANGE" -- countries.json) ]]; then
      echo "No changes to countries.json detected, skipping deploy."
      exit
    fi
    start_viewer_sinatra
    build_viewer_static
    deploy_viewer_static
  fi
}

main
