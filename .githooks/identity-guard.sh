#!/usr/bin/env bash
# Identity guard — keep cross-identity references out of this repository.
#
# This repo is published under a single identity. References belonging to a
# separate one must never land here, whether in file contents, in filenames,
# in commit messages, or in commit author/committer fields.
#
# The banned-pattern list is deliberately NOT tracked in this repo: writing
# those strings into a tracked file would publish the very things the guard
# exists to suppress. It lives machine-local, the same way the WireGuard
# endpoint hostname lives in /etc/wireguard/wg1.endpoint. Override its
# location with IDENTITY_GUARD_PATTERNS.
#
# Modes:
#   identity-guard.sh --staged      scan staged content + filenames (pre-commit)
#   identity-guard.sh --msg <file>  scan a prepared commit message (commit-msg)
#   identity-guard.sh --all         audit every blob, message and identity in
#                                   all reachable history (manual pre-push run)
#
# Fails closed: a missing, unreadable or empty pattern file blocks the commit
# rather than letting it through unchecked.

set -uo pipefail

PATTERNS="${IDENTITY_GUARD_PATTERNS:-/etc/nixos-identity-guard/patterns.txt}"

die() {
	printf 'identity-guard: %s\n' "$1" >&2
	shift
	[ "$#" -gt 0 ] && printf '%s\n' "$@" >&2
	exit 1
}

if [ ! -r "$PATTERNS" ]; then
	die "cannot read pattern file: $PATTERNS" \
		"" \
		"The guard fails closed rather than allow an unchecked commit." \
		"Create it (one extended-regex per line, '#' comments allowed), or set" \
		"IDENTITY_GUARD_PATTERNS to its location. Keep it OUTSIDE the repo." \
		"It must be readable by the user running git."
fi

PATFILE="$(mktemp)" || die "mktemp failed"
FOUND="$(mktemp)" || die "mktemp failed"
trap 'rm -f "$PATFILE" "$FOUND"' EXIT

grep -vE '^[[:space:]]*(#|$)' -- "$PATTERNS" >"$PATFILE"
[ -s "$PATFILE" ] || die "pattern file contains no usable patterns: $PATTERNS"

# grep the pattern file against stdin; prefix each hit with a label.
scan_stdin() {
	grep -nEi -f "$PATFILE" -- - 2>/dev/null | while IFS= read -r hit; do
		printf '  %s:%s\n' "$1" "$hit" >>"$FOUND"
	done
}

# The author/committer git will actually stamp on this commit. Checked because
# GIT_AUTHOR_* / GIT_COMMITTER_* environment variables silently override
# .gitconfig, so `git config user.email` can report the right identity while
# every commit is recorded under the wrong one.
check_identity() {
	local var ident
	for var in GIT_AUTHOR_IDENT GIT_COMMITTER_IDENT; do
		ident="$(git var "$var" 2>/dev/null)"
		printf '%s\n' "$ident" | grep -qEi -f "$PATFILE" &&
			printf '  %s: %s\n     (unset the %s_NAME/_EMAIL env vars — they override .gitconfig)\n' \
				"$var" "$ident" "${var%_IDENT}" >>"$FOUND"
	done
}

mode_staged() {
	check_identity
	# --diff-filter=ACMR: added/copied/modified/renamed. Deletions can't leak.
	while IFS= read -r -d '' f; do
		printf '%s\n' "$f" | grep -qEi -f "$PATFILE" &&
			printf '  %s: banned text in the filename itself\n' "$f" >>"$FOUND"
		git show ":$f" 2>/dev/null | scan_stdin "$f"
	done < <(git diff --cached --name-only --diff-filter=ACMR -z)
}

mode_msg() {
	# Strip the comment block git appends; it never reaches the stored message.
	grep -v '^#' -- "$1" | scan_stdin "commit message"
}

mode_all() {
	# Every blob reachable from every ref.
	while read -r sha blobpath; do
		git cat-file blob "$sha" </dev/null 2>/dev/null |
			grep -qEi -f "$PATFILE" &&
			printf '  blob %s (%s)\n' "$blobpath" "$sha" >>"$FOUND"
	done < <(git rev-list --objects --all |
		git cat-file --batch-check='%(objecttype) %(objectname) %(rest)' |
		awk '$1 == "blob" { print $2, $3 }')

	# Commit messages and author/committer identities.
	git log --all --format='%H%x09%an <%ae>%x09%cn <%ce>' |
		grep -Ei -f "$PATFILE" | while IFS= read -r hit; do
		printf '  identity %s\n' "$hit" >>"$FOUND"
	done

	while read -r commit; do
		git log -1 --format='%B' "$commit" | grep -qEi -f "$PATFILE" &&
			printf '  message %s\n' "$commit" >>"$FOUND"
	done < <(git rev-list --all)
}

case "${1-}" in
--staged) mode_staged ;;
--msg) [ -n "${2-}" ] || die "--msg requires a file argument"; mode_msg "$2" ;;
--all) mode_all ;;
*) die "usage: identity-guard.sh --staged | --msg <file> | --all" ;;
esac

if [ -s "$FOUND" ]; then
	{
		printf '\nidentity-guard: BLOCKED — cross-identity reference detected\n\n'
		sort -u -- "$FOUND"
		printf '\nRemove the reference before committing.\n'
		printf 'False positive? Adjust the patterns in %s\n' "$PATTERNS"
		printf 'Deliberate override: git commit --no-verify\n\n'
	} >&2
	exit 1
fi

[ "${1-}" = "--all" ] && printf 'identity-guard: all history clean\n'
exit 0
