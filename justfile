dir_build := "result"

default: build test

build: build-nix

build-nix:
    nix build --show-trace

test: test-bats

test-bats: build-nix
    just zz-tests_bats/test --bin-dir {{justfile_directory()}}/{{dir_build}}/bin --allow-unix-sockets
