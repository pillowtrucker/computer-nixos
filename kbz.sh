#!/usr/bin/env bash
# kbz — bugs.kde.org wrapper around python-bugzilla.
# Installed system-wide via /etc/nixos/configuration.nix:
#   (writeShellScriptBin "kbz" (builtins.readFile ./kbz.sh))
# Auth comes from ~/.bugzillarc ([bugs.kde.org] api_key = ...). For
# `kbz mine` also add a `user = <email>` line to that section (the file
# is machine-local and ignored by python-bugzilla itself).
set -euo pipefail

# NOTE: the /rest suffix is load-bearing — it steers python-bugzilla to its
# REST backend (URL heuristic in base.py). On the default XML-RPC backend
# bugs.kde.org rejects --quicksearch and --savedsearch with
# "Fault 1000: no search terms", and silently ignores email-role filters.
BZ="https://bugs.kde.org/rest"
RC="$HOME/.bugzillarc"

usage() {
  cat <<'EOF'
kbz — bugs.kde.org Bugzilla CLI (python-bugzilla wrapper)

usage:
  kbz show <id>...       full details of one or more bugs
  kbz mine [--all]       bugs where you are reporter/assignee/CC
                         (default: open only; --all includes closed)
  kbz s <terms...>       quicksearch, e.g. kbz s plasma crash on wayland
  kbz help               this help
  anything else          passed through to python-bugzilla verbatim,
                         e.g. kbz query --field component=general
                              kbz modify 500000 --status CONFIRMED
                              kbz new --product ... (see kbz help new)

Auth: API key in ~/.bugzillarc ([bugs.kde.org] api_key = ...).
EOF
}

die() { echo "kbz: $*" >&2; exit 1; }
bz() { bugzilla --bugzilla "$BZ" "$@"; }

user_email() {
  sed -n '/^\[bugs\.kde\.org\]/,/^\[/ s/^user *= *//p' "$RC" 2>/dev/null | head -1
}

cmd="${1-}"
case "$cmd" in
  ""|-h|--help|help)
    usage
    [ "$cmd" = help ] && bz --help
    ;;

  show)
    [ $# -ge 2 ] || die "show needs one or more bug ids"
    shift
    bz query --bug_id "$(IFS=,; echo "$*")" --full
    ;;

  mine)
    shift
    all=0
    if [ "${1-}" = "--all" ]; then all=1; shift; fi
    u="$(user_email)"
    [ -n "$u" ] || die "add a 'user = <email>' line to the [bugs.kde.org] section of $RC"
    extra=()
    [ "$all" = 0 ] && extra=(--field resolution=---)
    ids=()
    declare -A seen=()
    # role OR is done client-side: the legacy email1/emailN server mechanism
    # is silently ignored by bugs.kde.org, but per-field email params work.
    for f in creator cc assigned_to; do
      while IFS= read -r line; do
        id="${line%% *}"
        if [ -n "$id" ] && [ -z "${seen[$id]:-}" ]; then
          seen[$id]=1
          ids+=("$id")
        fi
      done < <(bz query --field "$f=$u" "${extra[@]}" \
                 --outputformat '%{id} %{status}' 2>/dev/null)
    done
    if [ "${#ids[@]}" = 0 ]; then
      echo "kbz: no bugs where $u is reporter, assignee or CC"
      exit 0
    fi
    joined="$(printf '%s\n' "${ids[@]}" | sort -n | paste -sd, -)"
    bz query --bug_id "$joined" \
      --outputformat '%{id} %{status} %{component}: %{summary}'
    ;;

  saved)
    die "saved searches are broken on bugs.kde.org (Fault 1000 / hang even via raw REST)"
    ;;

  s)
    shift
    [ $# -ge 1 ] || die "s needs search terms"
    bz query --quicksearch "$*" --outputformat '%{id} %{status} %{component}: %{summary}'
    ;;

  *)
    bz "$@"
    ;;
esac
