#!/bin/bash
# Overview of a project's health: GitHub stats, traffic, release artifact
# downloads, and AUR package stats.

set -uo pipefail

DEFAULT_REPO="zackb/tether"
JSON_ONLY=false

usage() {
    cat <<EOF
Usage: ${0##*/} [--json] [owner/repo | repo]

Defaults to $DEFAULT_REPO. A bare name is prefixed with "zackb/".
AUR packages are looked up as <name>-bin, <name>-git and <name>.

  --json   print the aggregated report as JSON instead of text
EOF
}

REPO=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json) JSON_ONLY=true ;;
        -h | --help)
            usage
            exit 0
            ;;
        -*)
            echo "unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *) REPO="$1" ;;
    esac
    shift
done

for cmd in gh jq curl; do
    command -v "$cmd" >/dev/null || {
        echo "$cmd is required" >&2
        exit 1
    }
done

REPO="${REPO:-$DEFAULT_REPO}"
[[ "$REPO" == */* ]] || REPO="zackb/$REPO"
NAME="${REPO#*/}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

gh api "repos/$REPO" >"$TMP/repo.json" 2>/dev/null || {
    echo "cannot read repos/$REPO (missing repo or bad auth)" >&2
    exit 1
}

gh api "repos/$REPO/releases" --paginate --slurp 2>/dev/null | jq -c 'add // []' >"$TMP/releases.json" ||
    echo '[]' >"$TMP/releases.json"
[[ -s "$TMP/releases.json" ]] || echo '[]' >"$TMP/releases.json"

# traffic endpoints need push access; absent for repos we don't own
for ep in views clones popular/referrers popular/paths; do
    out="$TMP/$(basename "$ep").json"
    gh api "repos/$REPO/traffic/$ep" >"$out" 2>/dev/null || echo null >"$out"
done

# ponytail: first page only, so both cap at 100. Paginate if a repo outgrows it.
count_api() { gh api "$1" 2>/dev/null | jq 'if type == "array" then length else 0 end' 2>/dev/null; }
PULLS=$(count_api "repos/$REPO/pulls?state=open&per_page=100")
CONTRIBUTORS=$(count_api "repos/$REPO/contributors?per_page=100&anon=1")
PULLS=${PULLS:-0}
CONTRIBUTORS=${CONTRIBUTORS:-0}

AUR_ERR=""
AUR_STATUS=$(curl -s --retry 3 --retry-delay 1 --retry-all-errors --max-time 20 -o "$TMP/aur.json" -w '%{http_code}' \
    "https://aur.archlinux.org/rpc/v5/info?arg[]=$NAME-bin&arg[]=$NAME-git&arg[]=$NAME")
# an empty result means "not in the AUR"; a bad response means we don't know
jq -e 'has("results")' "$TMP/aur.json" >/dev/null 2>&1 || {
    AUR_ERR="lookup failed (HTTP ${AUR_STATUS:-000})"
    echo '{"results": []}' >"$TMP/aur.json"
}

REPORT=$(jq -n \
    --arg repo "$REPO" \
    --slurpfile r "$TMP/repo.json" \
    --slurpfile rel "$TMP/releases.json" \
    --slurpfile views "$TMP/views.json" \
    --slurpfile clones "$TMP/clones.json" \
    --slurpfile refs "$TMP/referrers.json" \
    --slurpfile paths "$TMP/paths.json" \
    --slurpfile aur "$TMP/aur.json" \
    --arg aur_error "$AUR_ERR" \
    --argjson pulls "$PULLS" \
    --argjson contributors "$CONTRIBUTORS" '
    def kind:
        ascii_downcase
        | if endswith(".appimage") then "AppImage"
          elif endswith(".deb") then "deb"
          elif endswith(".rpm") then "rpm"
          elif endswith(".flatpak") then "flatpak"
          elif endswith(".pkg.tar.zst") then "pkg.tar.zst"
          elif endswith(".tar.gz") or endswith(".tgz") then "tar.gz"
          elif endswith(".tar.xz") then "tar.xz"
          elif endswith(".zip") then "zip"
          elif endswith(".sig") or endswith(".asc") or endswith(".sha256") then "signature"
          else "other" end;
    def by_type: [.[] | .assets[] | {k: (.name | kind), n: .download_count}]
        | group_by(.k) | map({key: .[0].k, value: (map(.n) | add)}) | from_entries;
    def total: [.[] | .assets[].download_count] | add // 0;

    ($r[0]) as $r | ($views[0]) as $views | ($clones[0]) as $clones |
    ($refs[0]) as $refs | ($paths[0]) as $paths | ($aur[0]) as $aur |
    ($rel[0] | sort_by(.published_at) | reverse) as $rel |
    ($rel | map(select(.draft | not)) | first) as $latest |
    {
      repo: $repo,
      github: {
        name: $r.name,
        description: $r.description,
        homepage: $r.homepage,
        language: $r.language,
        license: ($r.license.spdx_id // null),
        topics: $r.topics,
        archived: $r.archived,
        stars: $r.stargazers_count,
        forks: $r.forks_count,
        watchers: $r.subscribers_count,
        open_issues: ($r.open_issues_count - $pulls),
        open_prs: $pulls,
        contributors: $contributors,
        size_kb: $r.size,
        created_at: $r.created_at,
        pushed_at: $r.pushed_at
      },
      traffic: (if $views == null then null else {
        views: {count: $views.count, uniques: $views.uniques},
        clones: {count: $clones.count, uniques: $clones.uniques},
        referrers: ($refs // [] | map({name: .referrer, count, uniques})[:5]),
        paths: ($paths // [] | map({path, count, uniques})[:5])
      } end),
      releases: {
        count: ($rel | length),
        latest: (if $latest == null then null else {
          tag: $latest.tag_name,
          published_at: $latest.published_at,
          downloads: ([$latest.assets[].download_count] | add // 0),
          by_type: ([$latest] | by_type)
        } end),
        by_type: ($rel | by_type),
        total: ($rel | total),
        recent: ($rel[:10] | map({tag: .tag_name, published_at, downloads: ([.assets[].download_count] | add // 0)}))
      },
      aur_error: (if $aur_error == "" then null else $aur_error end),
      aur: ($aur.results // [] | map({
        name: .Name, version: .Version, votes: .NumVotes, popularity: .Popularity,
        out_of_date: .OutOfDate, maintainer: .Maintainer,
        first_submitted: .FirstSubmitted, last_modified: .LastModified
      }))
    }')

if [[ "$JSON_ONLY" == true ]]; then
    echo "$REPORT"
    exit 0
fi

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    B=$(tput bold) DIM=$(tput dim) C=$(tput setaf 6) R=$(tput sgr0)
else
    B="" DIM="" C="" R=""
fi

# "3d ago" from an ISO 8601 timestamp
ago() {
    local secs=$(($(date +%s) - $(date -d "$1" +%s)))
    if ((secs < 3600)); then echo "$((secs / 60))m ago"
    elif ((secs < 86400)); then echo "$((secs / 3600))h ago"
    else echo "$((secs / 86400))d ago"; fi
}

q() { jq -r "$1" <<<"$REPORT"; }

printf '%s%s%s — %s\n' "$B" "$(q .github.name)" "$R" "$(q '.github.description // "no description"')"
printf '  %s%s · %s · created %s · last push %s%s\n\n' "$DIM" \
    "$(q '[.github.license, .github.language] | map(select(.)) | join(" · ")')" \
    "$(q '.github.topics | if length > 0 then join(", ") else "no topics" end')" \
    "$(q .github.created_at | cut -dT -f1)" "$(ago "$(q .github.pushed_at)")" "$R"

printf '%sGitHub%s\n' "$C" "$R"
q '.github | "  Stars \(.stars)    Forks \(.forks)    Watchers \(.watchers)    Open issues \(.open_issues)    Open PRs \(.open_prs)    Contributors \(.contributors)"'

if [[ "$(q .traffic)" == "null" ]]; then
    printf '\n%sTraffic%s\n  %sunavailable (needs push access)%s\n' "$C" "$R" "$DIM" "$R"
else
    printf '\n%sTraffic (last 14 days)%s\n' "$C" "$R"
    q '.traffic | "  Views  \(.views.count) (\(.views.uniques) unique)     Clones \(.clones.count) (\(.clones.uniques) unique)"'
    q '.traffic.referrers | select(length > 0) | "  Referrers: " + (map("\(.name) \(.count)") | join(" · "))'
    q '.traffic.paths | select(length > 0) | "  Paths:     " + (map("\(.path) \(.count)") | join(" · "))'
fi

printf '\n%sReleases%s' "$C" "$R"
if [[ "$(q .releases.count)" == "0" ]]; then
    printf '\n  %snone published%s\n' "$DIM" "$R"
else
    printf ' (%s releases, latest %s %s)\n' "$(q .releases.count)" \
        "$(q .releases.latest.tag)" "$(ago "$(q .releases.latest.published_at)")"
    printf '  %-16s %10s %10s\n' "artifact" "all-time" "latest"
    q '.releases as $r | $r.by_type | to_entries | sort_by(-.value)[]
        | "\(.key)\t\(.value)\t\($r.latest.by_type[.key] // 0)"' |
        while IFS=$'\t' read -r k a l; do printf '  %-16s %10s %10s\n' "$k" "$a" "$l"; done
    printf '  %s%-16s %10s %10s%s\n' "$B" "total" "$(q .releases.total)" "$(q .releases.latest.downloads)" "$R"
    printf '\n  %srecent%s\n' "$DIM" "$R"
    q '.releases.recent[] | "\(.tag)\t\(.published_at[:10])\t\(.downloads)"' |
        while IFS=$'\t' read -r t d n; do printf '  %-12s %-12s %8s\n' "$t" "$d" "$n"; done
fi

printf '\n%sAUR%s\n' "$C" "$R"
if [[ -n "$AUR_ERR" ]]; then
    printf '  %s%s%s\n' "$DIM" "$AUR_ERR" "$R"
elif [[ "$(q '.aur | length')" == "0" ]]; then
    printf '  %sno %s-bin / %s-git / %s packages found%s\n' "$DIM" "$NAME" "$NAME" "$NAME" "$R"
else
    q '.aur | sort_by(.name)[] | "\(.name)\t\(.version)\t\(.votes) votes\tpop \(.popularity * 100 | round / 100)\tupdated \(.last_modified)\t\(if .out_of_date then "OUT OF DATE" else "" end)"' |
        while IFS=$'\t' read -r n v votes pop updated flag; do
            printf '  %-18s %-12s %-10s %-10s %s %s\n' "$n" "$v" "$votes" "$pop" \
                "updated $(date -d "@${updated#updated }" +%F)" "$flag"
        done
fi
