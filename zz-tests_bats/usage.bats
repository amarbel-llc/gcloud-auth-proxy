#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  export output
}

teardown() {
  teardown_test_home
}

function no_arguments_prints_usage { # @test
  run gcloud-auth-proxy
  assert_success
  assert_output --partial "Usage: gcloud-auth-proxy"
}

function help_flag_prints_usage { # @test
  run gcloud-auth-proxy --help
  assert_success
  assert_output --partial "Usage: gcloud-auth-proxy"
}

function short_help_flag_prints_usage { # @test
  run gcloud-auth-proxy -h
  assert_success
  assert_output --partial "Usage: gcloud-auth-proxy"
}

function unknown_command_exits_nonzero { # @test
  run gcloud-auth-proxy bogus-command
  assert_failure
  assert_output --partial "Unknown command: bogus-command"
}
