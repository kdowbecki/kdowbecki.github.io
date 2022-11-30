#!/usr/bin/env bash

yell() { echo "$0: $*" >&2; }
die() { yell "$*"; exit 42; }
try() { "$@" || die "Failed to: $*"; }

try bundle exec jekyll serve
