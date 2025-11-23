#!/bin/bash

REPO="zackb/hyprwat"
API_URL="https://api.github.com/repos/${REPO}/releases"
QUIET=false

if [[ "$1" == "--quiet" ]]; then
    QUIET=true
fi

if [[ "$QUIET" == false ]]; then
    echo "Fetching release data for ${REPO}..."
    echo ""
fi

RESPONSE=$(curl -s "${API_URL}")

# check if the response is valid json
if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
    if [[ "$QUIET" == false ]]; then
        echo "Error: Failed to fetch valid data from GitHub API"
        echo "Response: $RESPONSE"
    fi
    exit 1
fi

if [[ "$QUIET" == false ]]; then
    echo "Download counts for .tar.gz assets:"
    echo "===================================="
    echo ""

    echo "$RESPONSE" | jq -r '.[] | 
        .tag_name as $tag | 
        .name as $release_name |
        .assets[] | 
        select(.name | endswith(".tar.gz")) | 
        "\($release_name // $tag)|\(.name)|\(.download_count)"' | \
    while IFS='|' read -r release asset_name count; do
        printf "%-30s %-40s %10s downloads\n" "$release" "$asset_name" "$count"
    done

    echo ""
    echo "===================================="
fi

# calculate total
TOTAL=$(echo "$RESPONSE" | jq '[.[] | .assets[] | select(.name | endswith(".tar.gz")) | .download_count] | add // 0')

if [[ "$QUIET" == true ]]; then
    echo "$TOTAL"
else
    echo "Total .tar.gz downloads: $TOTAL"
    echo "Press [ENTER] to close."
    read
fi
