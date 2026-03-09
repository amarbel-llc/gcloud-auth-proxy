#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  export output
}

teardown() {
  teardown_test_home
}

function setup_remote_requires_host_argument { # @test
  run gcloud-auth-proxy setup-remote
  assert_failure
  assert_output --partial "Usage: gcloud-auth-proxy setup-remote <ssh-host>"
}
