#! /usr/bin/env bats

setup() {
  load "$(dirname "$BATS_TEST_FILE")/common.bash"
  setup_test_home
  setup_fake_gcloud
  start_proxy
  export output
}

teardown() {
  stop_proxy
  teardown_test_home
}

function health_endpoint_returns_200 { # @test
  run curl -s --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/health
  assert_success
  assert_output "OK"
}

function token_endpoint_returns_fake_token { # @test
  run curl -s --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/token
  assert_success
  assert_output "$FAKE_TOKEN"
}

function unknown_path_returns_not_found { # @test
  run curl -s -o /dev/null -w "%{http_code}" \
    --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/nonexistent
  assert_success
  assert_output "404"
}

function health_endpoint_has_correct_content_type { # @test
  run curl -s -D - --unix-socket "$GCLOUD_AUTH_PROXY_SOCKET" http://localhost/health
  assert_success
  assert_output --partial "Content-Type: text/plain"
}
