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
echo "## Upstream release size (guideline: <=30 MB; skip when there is no release)"
if [[ -n "$repo_slug" ]]; then
    if release_json="$(gh release view --repo "$repo_slug" --json tagName,assets 2>/dev/null)"; then
        printf '%s' "$release_json" | jq -r --argjson limit 31457280 '
            .tagName as $t |
            (.assets // []) as $a |
            if ($a | length) == 0 then
                "- \($t): no downloadable assets — skip the 30 MB criterion"
            else
                ($a[] | "- \(.name): \(.size) bytes (\((.size / 1048576 * 10 | floor) / 10) MB)"),
                (($a | max_by(.size)) as $m |
                    "largest asset: \($m.name) \(((($m.size / 1048576) * 10 | floor) / 10)) MB — " +
                    (if $m.size <= $limit then "pass (<=30 MB)" else "caution (>30 MB, likely too heavy)" end)),
                "- note: this is the upstream package, not Tina'"'"'s DMG"
            end' 2>/dev/null \
            || echo "- release exists but assets could not be parsed"
    else
        echo "- no release — skip the 30 MB criterion; estimate from source/dependencies instead"
    fi
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
echo "- The 30 MB guideline applies to the upstream project's release package, not Tina's DMG."
echo "- If the upstream project has no release, skip that guideline and estimate from source/dependencies."
