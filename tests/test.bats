#!/usr/bin/env bats

# Standard DDEV add-on setup code taken from official DDEV add-ons.
setup() {
  set -eu -o pipefail
  export GITHUB_REPO=ddev-drupal-contrib-mkdocs
  TEST_BREW_PREFIX="$(brew --prefix 2>/dev/null || true)"
  export BATS_LIB_PATH="${BATS_LIB_PATH}:${TEST_BREW_PREFIX}/lib:/usr/lib/bats"
  bats_load_library bats-assert
  bats_load_library bats-file
  bats_load_library bats-support

  # shellcheck disable=SC2155
  export DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." >/dev/null 2>&1 && pwd)"
  # shellcheck disable=SC2155
  export PROJNAME="test-$(basename "${GITHUB_REPO}")"

  mkdir -p ~/tmp
  # shellcheck disable=SC2155
  export TESTDIR=$(mktemp -d ~/tmp/${PROJNAME}.XXXXXX)
  export DDEV_NONINTERACTIVE=true
  export DDEV_NO_INSTRUMENTATION=true
  ddev delete -Oy "${PROJNAME}" >/dev/null 2>&1 || true

  cd "${TESTDIR}"
  run ddev config --project-name="${PROJNAME}" --project-tld=ddev.site
  assert_success
  run ddev start -y
  assert_success
}

# Standard DDEV add-on tear down code taken from official DDEV add-ons.
teardown() {
  set -eu -o pipefail
  echo "# Tearing down test environment" >&3
  cd ${TESTDIR} || ( printf "unable to cd to ${TESTDIR}\n" && exit 1 )
  ddev delete -Oy ${PROJNAME} >/dev/null 2>&1
  cd ..
  [ "${TESTDIR}" != "" ] && rm -rf ${TESTDIR}
  echo "# Teardown complete" >&3
}

check_layout() {
  echo "Checking Drupal contrib MkDocs layout" >&3
  run test -f mkdocs.yml
  assert_success
  run test -f docs/index.md
  assert_success
  run test ! -d docs/docs
  assert_success
  run test -f .ddev/mkdocs/mkdocs.yml
  assert_success
}

health_checks() {
  echo "Checking mkdocs health" >&3
  run ddev exec wget http://mkdocs:8000 -q -O -
  assert_output --partial "Welcome to MkDocs"
  https_port=$(ddev exec -s web printenv DDEV_ROUTER_HTTPS_PORT)
  if [ "${https_port}" = "443" ]; then
    docs_url="https://docs.${PROJNAME}.ddev.site/"
  else
    docs_url="https://docs.${PROJNAME}.ddev.site:${https_port}/"
  fi
  run curl -fk "${docs_url}"
  assert_success
  assert_output --partial "Welcome to MkDocs"
}

check_build_mkdocs() {
  echo "Checking mkdocs build" >&3
  ddev mkdocs build
}

@test "Install from folder" {
  set -eu -o pipefail
  cd ${TESTDIR}
  echo "# ddev get ${DIR} with project ${PROJNAME} in ${TESTDIR} ($(pwd))" >&3
  ddev get ${DIR}
  echo "Installed add-on from directory, restarting ddev" >&3
  ddev restart -y
  echo "Testing mkdocs" >&3

  check_layout

  health_checks

  check_build_mkdocs
}
