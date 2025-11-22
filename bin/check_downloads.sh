#!/bin/bash

REPO="zackb/hyprwat"

API_URL="https://api.github.com/repos/${REPO}/releases"

echo "Fetching release data for ${REPO}..."
echo ""

RESPONSE=$(curl -s "${API_URL}")

# check if the response is valid json
if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
    echo "Error: Failed to fetch valid data from GitHub API"
    echo "Response: $RESPONSE"
    exit 1
fi

echo "Download counts for .tar.gz assets:"
echo "===================================="
echo ""

TOTAL_DOWNLOADS=0

echo "$RESPONSE" | jq -r '.[] | 
    .tag_name as $tag | 
    .name as $release_name |
    .assets[] | 
    select(.name | endswith(".tar.gz")) | 
    "\($release_name // $tag)|\(.name)|\(.download_count)"' | \
while IFS='|' read -r release asset_name count; do
    printf "%-30s %-40s %10s downloads\n" "$release" "$asset_name" "$count"
    TOTAL_DOWNLOADS=$((TOTAL_DOWNLOADS + count))
done

# calculate total separately since the while loop runs in a subshell
TOTAL=$(echo "$RESPONSE" | jq '[.[] | .assets[] | select(.name | endswith(".tar.gz")) | .download_count] | add // 0')

echo ""
echo "===================================="
echo "Total .tar.gz downloads: $TOTAL"
