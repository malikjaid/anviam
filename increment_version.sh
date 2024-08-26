#!/bin/bash

# Fetch all tags from remote
git fetch --tags

# Determine the current branch
CURRENT_BRANCH=$(git branch --show-current)

# Set initial version based on branch
if [ "$CURRENT_BRANCH" == "malikt" ]; then
    VERSION_FILE="version-main.php"
    INITIAL_VERSION="220.0.0"
elif [ "$CURRENT_BRANCH" == "main" ]; then
    VERSION_FILE="version-dev.php"
    INITIAL_VERSION="230.1.0-beta"
else
    VERSION_FILE="version-$CURRENT_BRANCH.php"
    INITIAL_VERSION="1223.0.0-$CURRENT_BRANCH"
fi

# Check if an initial version is set via an environment variable or a specific file
if [ -n "$INITIAL_VERSION" ]; then
    NEW_VERSION="$INITIAL_VERSION"
    # Reset INITIAL_VERSION after the first run
    INITIAL_VERSION=""
else
    # Get the latest tag for the current branch
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

# Form the new tag
NEW_TAG="v$NEW_VERSION"

# Check if the new tag already exists and increment if necessary
while git rev-parse "$NEW_TAG" >/dev/null 2>&1; do
    echo "Tag '$NEW_TAG' already exists. Incrementing version."
    PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
    NEW_TAG="v$NEW_VERSION"
done

# Update the version file with the new version
if [ -f "$VERSION_FILE" ]; then
    echo "$VERSION_FILE found."
    # Update the version in the PHP file
    sed -i "s/\(\$version\s*=\s*'\)[vV]*[0-9]\+\.[0-9]\+\.[0-9]\+\(';.*\)/\1$NEW_VERSION\2/" "$VERSION_FILE"
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

# Create release notes
RELEASE_BODY=$(conventional-changelog -p angular -i CHANGELOG.md -s -r 0)

# Fetch the latest commit messages since the last tag, excluding version file updates
COMMITS=$(git log $LATEST_TAG..HEAD --pretty=format:"%h %s" --no-merges | grep -v "chore: Update version to")

# Combine the release notes and commit messages, ensuring proper formatting
if [[ -z "$COMMITS" ]]; then
    RELEASE_NOTES="$RELEASE_BODY"
else
    RELEASE_NOTES="$RELEASE_BODY"$'\n\n'"$COMMITS"
fi

# Create a new release with the combined notes
gh release create "$NEW_TAG" --notes "$RELEASE_NOTES"
