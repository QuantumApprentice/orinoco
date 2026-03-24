#!/usr/bin/env bash

set -euo pipefail

CMD="${1:-}"

run() {
  bundle exec ruby -e "require 'dotenv'; Dotenv.load('.env.dev.orinoco'); exec 'c:\\Ruby40-x64\\bin\\ruby.exe', './bin/rails', $*"
}

case "$CMD" in
migrate)
  run "'db:migrate'"
  ;;
routes | r)
  run "'routes'"
  ;;
spec | sp)
  run "'spec'"
  ;;
bridge | obs)
  run "'runner', 'ObsBridgeWorker.new.run'"
  ;;
tailwind | tw)
  run "'tailwindcss:build'"
  ;;
server | s)
  run "'server', '-p', '33230', '-b', '0.0.0.0', '-P', 'tmp/pids/server.foreman.development.pid'"
  ;;
*)
  echo "Usage: $0 {migrate|routes|tailwind|server}"
  exit 1
  ;;
esac
