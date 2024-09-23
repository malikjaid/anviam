#!/bin/bash

# Fetch all tags from remote
git fetch --tags

# Check if an initial version is set via an environment variable or a specific file
INITIAL_VERSION=""  # Set this to "9000.0.0" only for the first run

# Use the initial version if specified; otherwise, continue from the latest tag
if [ -n "$INITIAL_VERSION" ]; then
    NEW_VERSION="$INITIAL_VERSION"
    # Reset INITIAL_VERSION after the first run
    INITIAL_VERSION=""
else
    # Get the latest tag (version)
    LATEST_TAG=$(git describe --tags `git rev-list --tags --max-count=1`)

    # Extract the version numbers from the tag
    IFS='.' read -r -a VERSION_PARTS <<< "${LATEST_TAG:1}"

    MAJOR=${VERSION_PARTS[0]}
    MINOR=${VERSION_PARTS[1]}
    PATCH=${VERSION_PARTS[2]}

    # Increment the patch version
    PATCH=$((PATCH + 1))

    # Form the new version string
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
fi

# Create the new tag
NEW_TAG="v$NEW_VERSION"

# Check if the new tag already exists and handle the error
# if git rev-parse "$NEW_TAG" >/dev/null 2>&1; then
#     echo "Error: Tag '$NEW_TAG' already exists."
#     exit 1
# fi

# Determine the current branch
CURRENT_BRANCH=$(git branch --show-current)

# Tag and create a new release
git tag -a "$NEW_TAG" -m "$NEW_TAG"
git push origin "$NEW_TAG"

# Create release notes
RELEASE_BODY=$(conventional-changelog -p angular -i CHANGELOG.md -s -r 0)

# Fetch the latest commit messages since the last tag
COMMITS=$(git log $LATEST_TAG..HEAD --pretty=format:"%h %s" --no-merges)

# Combine the release notes and commit messages, ensuring proper formatting
if [[ -z "$COMMITS" ]]; then
    RELEASE_NOTES="$RELEASE_BODY"
else
    RELEASE_NOTES="$RELEASE_BODY"$'\n\n'"$COMMITS"
fi

# Create a new release with the combined notes
gh release create "$NEW_TAG" --notes "$RELEASE_NOTES"
