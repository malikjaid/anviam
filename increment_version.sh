#!/bin/bash

# Fetch all tags from remote
git fetch --tags

# Determine the current branch
CURRENT_BRANCH=$(git branch --show-current)

# Set version file and initial version based on the branch
case "$CURRENT_BRANCH" in
    "main")
        VERSION_FILE="version-main.php"
        INITIAL_VERSION="9999.0.1"
        ;;
    "malikt")
        VERSION_FILE="version-malikt.php"
        INITIAL_VERSION="8888.0.0"
        ;;
    *)
        VERSION_FILE="version-$CURRENT_BRANCH.php"
        INITIAL_VERSION="1223.0.0-$CURRENT_BRANCH"
        ;;
esac

# Get the latest tag for the current branch
LATEST_TAG=$(git tag --list "v$INITIAL_VERSION" | grep "$CURRENT_BRANCH" | sort -V | tail -n1)

# Check if the latest tag is empty, and set the version to INITIAL_VERSION if so
if [ -z "$LATEST_TAG" ]; then
    NEW_VERSION="$INITIAL_VERSION"
else
    # Extract the version numbers from the tag
    IFS='.' read -r -a VERSION_PARTS <<< "${LATEST_TAG//[!0-9.]/}"

    if [ ${#VERSION_PARTS[@]} -eq 3 ]; then
        MAJOR=${VERSION_PARTS[0]}
        MINOR=${VERSION_PARTS[1]}
        PATCH=${VERSION_PARTS[2]}

        # Increment the patch version
        PATCH=$((PATCH + 1))

        # Form the new version string
        NEW_VERSION="$MAJOR.$MINOR.$PATCH"
    else
        echo "Error: Failed to parse version from $LATEST_TAG"
        exit 1
    fi
fi

# Form the new tag
NEW_TAG="v$NEW_VERSION-$CURRENT_BRANCH"

# Debugging info
echo "LATEST_TAG: $LATEST_TAG"
echo "NEW_VERSION: $NEW_VERSION"
echo "NEW_TAG: $NEW_TAG"

# Check if the new tag already exists and increment if necessary
while git rev-parse "$NEW_TAG" >/dev/null 2>&1; do
    echo "Tag '$NEW_TAG' already exists. Incrementing version."
    PATCH=$((PATCH + 1))
    NEW_VERSION="$MAJOR.$MINOR.$PATCH"
    NEW_TAG="v$NEW_VERSION-$CURRENT_BRANCH"

    # Debugging info
    echo "Updated NEW_VERSION: $NEW_VERSION"
    echo "Updated NEW_TAG: $NEW_TAG"
done

# Update the version file with the new version
if [ -f "$VERSION_FILE" ]; then
    echo "$VERSION_FILE found."
    # Update the version in the PHP file
    sed -i "s/\(\$version\s*=\s*'\)[^']*';/\1$NEW_VERSION';/" "$VERSION_FILE"
    if [ $? -eq 0 ]; then
        echo "Updated $VERSION_FILE with version: $NEW_VERSION"
    else
        echo "Error: Failed to update $VERSION_FILE!"
        exit 1
    fi

    # Debugging info: Check for changes
    git diff "$VERSION_FILE"
else
    echo "Error: $VERSION_FILE not found!"
    exit 1
fi

# Check for changes and commit them
if git diff --quiet; then
    echo "No changes to commit."
else
    git add "$VERSION_FILE"
    git commit -m "chore: Update version to $NEW_VERSION in $VERSION_FILE"
    git push origin "$CURRENT_BRANCH"
fi

# Tag and create a new release
git tag -a "$NEW_TAG" -m "$NEW_TAG"
git push origin "$NEW_TAG"

# Create release notes
RELEASE_BODY=$(npx conventional-changelog-cli -p angular -i CHANGELOG.md -s -r 0)

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