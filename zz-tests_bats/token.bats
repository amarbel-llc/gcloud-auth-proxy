#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  setup_fake_gcloud
  export output
}

teardown() {
  stop_proxy
  teardown_test_home
}

function token_fails_when_no_socket { # @test
  export GCLOUD_AUTH_PROXY_SOCKET="$BATS_TEST_TMPDIR/nonexistent.sock"
  run gcloud-auth-proxy token
  assert_failure
  assert_output --partial "proxy socket not found"
}

function token_error_suggests_service_install { # @test
  export GCLOUD_AUTH_PROXY_SOCKET="$BATS_TEST_TMPDIR/nonexistent.sock"
  run gcloud-auth-proxy token
  assert_failure
  assert_output --partial "service-install"
}

function token_prints_token_value { # @test
  start_proxy
  run gcloud-auth-proxy token
  assert_success
  assert_output "$FAKE_TOKEN"
}

function token_export_flag_wraps_in_export { # @test
  start_proxy
  run gcloud-auth-proxy token --export
  assert_success
  assert_output "export CLOUDSDK_AUTH_ACCESS_TOKEN='${FAKE_TOKEN}'"
}
