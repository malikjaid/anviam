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
    IFS='.-' read -r MAJOR MINOR PATCH BRANCH <<< "${LATEST_TAG#v}"
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
    sed -i "s/\(\$version\s*=\s*'\)[vV]*[0-9]\+\.[0-9]\+\.[0-9]\+\('-.*\)/\1$NEW_VERSION\2/" "$VERSION_FILE"
    echo "Updated $VERSION_FILE with version: $NEW_VERSION"
else
    echo "Error: $VERSION_FILE not found!"
    exit 1
fi

# Commit the updated version file
git add "$VERSION_FILE"
git commit -m "chore: Update version to $NEW_VERSION in $VERSION_FILE"

# Push the changes to the current branch
git push origin "$CURRENT_BRANCH"

# Tag and create a new release
git tag -a "$NEW_TAG" -m "$NEW_TAG"
git push origin "$NEW_TAG"

# Generate release notes
RELEASE_BODY=$(conventional-changelog -p angular -i CHANGELOG.md -s -r 0)

# Fetch the latest commit messages since the last tag, excluding version file updates
COMMITS=$(git log "$LATEST_TAG"..HEAD --pretty=format:"%h %s" --no-merges | grep -v "chore: Update version to")

# Combine the release notes and commit messages, ensuring proper formatting
if [[ -z "$COMMITS" ]]; then
    RELEASE_NOTES="$RELEASE_BODY"
else
    RELEASE_NOTES="$RELEASE_BODY"$'\n\n'"$COMMITS"
fi

# Create a new release with the combined notes
gh release create "$NEW_TAG" --notes "$RELEASE_NOTES"
