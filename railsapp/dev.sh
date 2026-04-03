#!/usr/bin/env bash

set -euo pipefail

CMD="${1:-}"
shift || true

run_rails() {
  bundle exec ruby -e "
    require 'dotenv'
    Dotenv.load('.env.dev.orinoco')
    exec 'c:\\Ruby40-x64\\bin\\ruby.exe', './bin/rails', *ARGV
  " -- "$@"
}

run_rspec() {
  bundle exec ruby -e "
    require 'dotenv'
    Dotenv.load('.env.test.orinoco')
    exec Gem.ruby, Gem.bin_path('rspec-core', 'rspec'), *ARGV
  " -- "$@"
}

run_test_migrate() {
  bundle exec ruby -e "
    require 'dotenv'
    Dotenv.load('.env.test.orinoco')
    exec Gem.ruby, './bin/rails', 'db:migrate', *ARGV
  " -- "$@"
}

case "$CMD" in
"" | help | -h | --help)
  cat <<EOF
Usage: $0 <rails-command-or-shortcut> [args...]

Shortcuts:
  migrate
  routes | r
  spec | sp
  bridge | obs
  tailwind | tw
  server | s
  generate | g
  console | c

Examples:
  $0 migrate
  $0 routes
  $0 g model EnabledAffordance name:string config:jsonb scene_name:string
  $0 spec
  $0 spec spec/models/enabled_affordance_spec.rb
  $0 spec spec/models/enabled_affordance_spec.rb:17
  $0 db:migrate:status
  $0 runner "puts Rails.env"
  $0 destroy model EnabledAffordance
EOF
  ;;
tmigrate)
  run_test_migrate "$@"
  ;;
migrate)
  run_rails db:migrate "$@"
  ;;
routes | r)
  run_rails routes "$@"
  ;;
spec | sp)
  run_rspec "$@"
  ;;
bridge | obs)
  run_rails runner "ObsBridgeWorker.new.run" "$@"
  ;;
tailwind | tw)
  run_rails tailwindcss:build "$@"
  ;;
server | s)
  run_rails server -p 33230 -b 0.0.0.0 -P tmp/pids/server.foreman.development.pid "$@"
  ;;
generate | g)
  run_rails generate "$@"
  ;;
console | c)
  run_rails console "$@"
  ;;
*)
  run_rails "$CMD" "$@"
  ;;
esac
