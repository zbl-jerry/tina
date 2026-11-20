#!/bin/zsh
# Static, read-only probe for a macOS/open-source project.
# Usage: probe_macos_project.sh <local-path|github-owner/repo|https://github.com/owner/repo>
# It never builds or executes the target project.
set -euo pipefail

input="${1:-}"
if [[ -z "$input" ]]; then
    echo "usage: $0 <local-path|owner/repo|github-url>" >&2
    exit 2
fi

tmp=""
cleanup() { [[ -n "$tmp" ]] && rm -rf "$tmp"; }
trap cleanup EXIT

repo_slug=""
case "$input" in
    http://*|https://*|git@*)
        repo_slug="$(printf '%s' "$input" | sed -E 's#^(git@github.com:|https?://github.com/)##; s#\.git$##; s#/$##')"
        ;;
    */*)
        [[ -d "$input" ]] || repo_slug="$input"
        ;;
esac

if [[ -n "$repo_slug" ]]; then
    echo "## Repository"
    gh repo view "$repo_slug" --json nameWithOwner,description,primaryLanguage,stargazerCount,pushedAt,defaultBranchRef,latestRelease 2>/dev/null \
        | jq -r '"repo: \(.nameWithOwner)\ndescription: \(.description // "-")\nlanguage: \(.primaryLanguage.name // "-")\nstars: \(.stargazerCount)\npushed: \(.pushedAt)\ndefault branch: \(.defaultBranchRef.name // "-")\nlatest release: \(.latestRelease.tagName // "-") @ \(.latestRelease.publishedAt // "-")"' 2>/dev/null \
        || echo "（无法读取仓库元数据，继续做本地探测）"
    tmp="$(mktemp -d)"
    echo
    echo "## Clone (shallow, no execution)"
    if git clone --depth 1 --quiet "https://github.com/$repo_slug.git" "$tmp/repo" 2>/dev/null; then
        root="$tmp/repo"
        echo "cloned: $root"
    else
        echo "clone failed; treat remaining output as unavailable" >&2
        exit 1
    fi
else
    root="$input"
    echo "## Local path"
    echo "$root"
fi

echo
echo "## Project type"
for marker in "*.xcodeproj" "Package.swift" "package.json" "Cargo.toml" "go.mod" "requirements.txt" "CMakeLists.txt"; do
    found=$(find "$root" -maxdepth 2 -name "$marker" -print -quit 2>/dev/null || true)
    [[ -n "$found" ]] && echo "- ${marker}: ${found#$root/}"
done
if [[ -f "$root/package.json" ]]; then
    if grep -q '"electron"' "$root/package.json" 2>/dev/null; then
        echo "- warning: Electron dependency"
    fi
fi

echo
echo "## Deployment target / minimum OS"
grep -RInE 'MACOSX_DEPLOYMENT_TARGET|LSMinimumSystemVersion|platforms[[:space:]]*:' \
    "$root" --include='*.pbxproj' --include='*.plist' --include='*.swift' --include='*.xcconfig' 2>/dev/null \
    | head -20 || echo "- not found"

echo
echo "## Dependencies"
for f in Package.swift package.json Cargo.toml go.mod requirements.txt; do
    [[ -f "$root/$f" ]] && { echo "- $f:"; sed -n '1,40p' "$root/$f" | sed 's/^/    /'; }
done

echo
echo "## Built .app size (if present)"
find "$root" -maxdepth 3 -name '*.app' -type d -print 2>/dev/null | while read -r app; do
    du -sh "$app"
done

echo
echo "## Release assets (compressed size reference)"
if [[ -n "$repo_slug" ]]; then
    gh release view --repo "$repo_slug" --json tagName,assets 2>/dev/null \
        | jq -r '.tagName as $t | .assets[]? | "- \(.name) \(.size) bytes (\(.size/1048576 | floor) MB) in \($t)"' 2>/dev/null \
        || echo "- no release assets or API unavailable"
fi

echo
echo "## Feature surface hints"
find "$root" -maxdepth 3 \( -iname 'README*' -o -iname 'CHANGELOG*' \) -type f -print 2>/dev/null | head -5
if [[ -f "$root/README.md" ]]; then
    echo "- README headings:"
    grep -E '^#{1,3} ' "$root/README.md" | head -20 | sed 's/^/    /'
fi

echo
echo "## Notes"
echo "- This probe is static. It does not build or run target code."
echo "- Size of an upstream release is reference only; estimate Tina's incremental size separately."
