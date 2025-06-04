#!/bin/bash
set -e
for test in tests/*.sh; do
  echo "Running $test"
  bash "$test"
done
