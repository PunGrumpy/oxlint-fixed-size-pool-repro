#!/bin/sh
# Runs oxlint in Docker with the VM's vm.overcommit_memory set to 0, then restores it.
# The setting is VM-wide, so the original value is put back on exit.
set -eu
docker run --rm --privileged -v "$PWD":/src:ro oven/bun:1 sh -c '
  original=$(cat /proc/sys/vm/overcommit_memory)
  trap "echo $original > /proc/sys/vm/overcommit_memory" EXIT
  cp -r /src /w && cd /w && rm -rf node_modules && bun install --frozen-lockfile >/dev/null
  grep -E "MemTotal|SwapTotal|CommitLimit" /proc/meminfo
  for mode in 1 0; do
    echo "$mode" > /proc/sys/vm/overcommit_memory
    for config in .oxlintrc.json .oxlintrc.native.json; do
      if bunx oxlint -c "$config" > out.txt 2>&1; then status=pass; else status="fail ($?)"; fi
      echo "overcommit_memory=$mode $config: $status"
      grep -m1 panicked out.txt || true
    done
  done
'
