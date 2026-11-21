#!/usr/bin/env zsh
# Prepare and push a release tag.
#
#   ./scripts/release.sh v1.3.0 [--dry-run] [--no-test]
#
# Makes build.zig.zon and macos/Info.plist carry the tag's version (committing
# the change only if they differ), pushes the branch, then creates and pushes
# the annotated tag, which triggers the release workflow.

set -euo pipefail

TAG=""
DRY_RUN=false
RUN_TESTS=true
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --no-test) RUN_TESTS=false ;;
        v*) TAG=$arg ;;
        *) echo "unknown argument: $arg" >&2; exit 1 ;;
    esac
done

if [[ ! $TAG =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "usage: $0 vMAJOR.MINOR.PATCH [--dry-run] [--no-test]" >&2
    exit 1
fi
VERSION=${TAG#v}

cd "${0:A:h:h}"
ZON=build.zig.zon
PLIST=macos/Info.plist
REMOTE=origin

die() { echo "error: $*" >&2; exit 1; }

BRANCH=$(git symbolic-ref --short HEAD) || die "detached HEAD"
[[ $BRANCH == main ]] || die "releases are cut from main (on $BRANCH)"
[[ -z $(git status --porcelain) ]] || die "working tree is not clean"

git fetch --quiet "$REMOTE" main --tags
read -r behind ahead <<<"$(git rev-list --left-right --count "$REMOTE/main...HEAD")"
(( behind == 0 )) || die "main is $behind commit(s) behind $REMOTE/main: git pull --rebase"
(( ahead == 0 )) || die "main is $ahead commit(s) ahead of $REMOTE/main: push or drop them first"
git rev-parse -q --verify "refs/tags/$TAG" >/dev/null && die "tag $TAG already exists"

zon_version() { sed -n 's/^[[:space:]]*\.version = "\(.*\)",/\1/p' "$ZON"; }
plist_get() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST"; }

typeset -a stale
[[ $(zon_version) == $VERSION ]] || stale+=("$ZON: $(zon_version)")
[[ $(plist_get CFBundleShortVersionString) == $VERSION ]] \
    || stale+=("$PLIST CFBundleShortVersionString: $(plist_get CFBundleShortVersionString)")
[[ $(plist_get CFBundleVersion) == $VERSION ]] \
    || stale+=("$PLIST CFBundleVersion: $(plist_get CFBundleVersion)")

if (( ${#stale} )); then
    echo "Out of date for $VERSION:"
    printf '  %s\n' "${stale[@]}"
else
    echo "Version files already at $VERSION."
fi

if $DRY_RUN; then
    echo "Dry run: would $( (( ${#stale} )) && echo "commit the bump, ")push $BRANCH and tag $TAG."
    exit 0
fi

if (( ${#stale} )); then
    sed -i '' "s/^\([[:space:]]*\.version = \"\).*\(\",\)/\1$VERSION\2/" "$ZON"
    /usr/libexec/PlistBuddy \
        -c "Set :CFBundleShortVersionString $VERSION" \
        -c "Set :CFBundleVersion $VERSION" "$PLIST"
    [[ $(zon_version) == $VERSION ]] || die "failed to update $ZON"
fi

if $RUN_TESTS; then
    zig build test
fi

echo "About to ${stale:+commit the bump, }push $BRANCH and tag $TAG to $REMOTE."
read -r "reply?Continue? [y/N] "
if [[ $reply != [yY] ]]; then
    git checkout -- "$ZON" "$PLIST"
    echo "Aborted; nothing was committed or pushed."
    exit 1
fi

if (( ${#stale} )); then
    git add "$ZON" "$PLIST"
    git commit -m "chore: release $TAG"
fi

git push "$REMOTE" "$BRANCH"
git tag -a "$TAG" -m "$TAG"
git push "$REMOTE" "$TAG"
echo "Pushed $TAG."
