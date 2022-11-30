#!/usr/bin/env bash

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 42; }
try() { "$@" || die "Failed to: $*"; }

rubyVersion=$(cat .ruby-version)
try rbenv install "$rubyVersion" --verbose

try bundle install
