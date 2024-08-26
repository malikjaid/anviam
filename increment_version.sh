#!/bin/bash

# Fetch all tags from remote
git fetch --tags

# Determine the current branch
CURRENT_BRANCH=$(git branch --show-current)

# Set version file based on the branch
case "$CURRENT_BRANCH" in
    "main")
        VERSION_FILE="version-main.php"
        ;;
    "malikt")
        VERSION_FILE="version-malikt.php"
        ;;
    *)
        echo "Error: Unsupported branch '$CURRENT_BRANCH'. Exiting."
        exit 1
        ;;
esac

# Get the latest tag for the current branch
LATEST_TAG=$(git tag --list "v*-$CURRENT_BRANCH" | sort -V | tail -n1)

if [ -z "$LATEST_TAG" ]; then
    # Initialize version if no tags exist
    MAJOR=0
    MINOR=0
    PATCH=0
else
    # Extract the version numbers from the tag
    VERSION_PART="${LATEST_TAG%%-$CURRENT_BRANCH}"
    VERSION_PART="${VERSION_PART#v}"
    IFS='.' read -r -a VERSION_PARTS <<< "$VERSION_PART"

    MAJOR=${VERSION_PARTS[0]}
    MINOR=${VERSION_PARTS[1]}
    PATCH=${VERSION_PARTS[2]}
fi

# Increment the patch version
PATCH=$((PATCH + 1))

# Form the new version string
NEW_VERSION="$MAJOR.$MINOR.$PATCH"

# Form the new tag
NEW_TAG="v$NEW_VERSION-$CURRENT_BRANCH"

# Check if the new tag already exists and handle the error
if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
    echo "Error: Tag '$NEW_TAG' already exists."
    exit 1
fi

# Update the version file with the new version
if [ -f "$VERSION_FILE" ]; then
    sed -i "s/\(\$version\s*=\s*'\)[^']*\('.*\)/\1$NEW_VERSION-$CURRENT_BRANCH\2/" "$VERSION_FILE"
    echo "Updated $VERSION_FILE with version: $NEW_VERSION-$CURRENT_BRANCH"
else
    echo "Error: $VERSION
