#!/bin/bash

set -e

ORG="shobhit-maple"

REPOS=(
  "maple-base" "maple-api-router-service"
)

MANIFEST_DIR="kubernetes"

GITHUB_TOKEN="$GITHUB_TOKEN"

# Ensure there are no arguments passed for namespace
if [ $# -gt 1 ]; then
  echo "Usage: $0 [--force]"
  exit 1
fi

FORCE=$1

apply_manifest() {
  local repo_url=$1
  local file=$2
  local url="$repo_url/$file"

  CONTENT=$(curl -sSL "$url")
  if [ -z "$CONTENT" ]; then
    return
  fi

  TMP_FILE=$(mktemp)
  echo "$CONTENT" > "$TMP_FILE"

  KIND=$(grep -m 1 'kind:' "$TMP_FILE" | awk '{print $2}')
  NAME=$(grep -m 1 'name:' "$TMP_FILE" | awk '{print $2}')
  MANIFEST_NAMESPACE=$(grep -m 1 'namespace:' "$TMP_FILE" | awk '{print $2}')

  # If no namespace is found in the manifest, skip this manifest
  if [ -z "$MANIFEST_NAMESPACE" ]; then
    echo "No namespace found in manifest $file, skipping..."
    rm "$TMP_FILE"
    return
  fi

  if [[ -z "$KIND" || -z "$NAME" ]]; then
    rm "$TMP_FILE"
    return
  fi

  if [[ "$FORCE" == "--force" ]]; then
    echo "Forcefully recreating $KIND $NAME in namespace $MANIFEST_NAMESPACE..."
    kubectl delete "$KIND" "$NAME" -n "$MANIFEST_NAMESPACE" --ignore-not-found
    echo "$CONTENT" | kubectl apply -f - -n "$MANIFEST_NAMESPACE"
  else
    if kubectl get "$KIND" "$NAME" -n "$MANIFEST_NAMESPACE" >/dev/null 2>&1; then
      if ! echo "$CONTENT" | kubectl diff -f - -n "$MANIFEST_NAMESPACE"; then
        echo "Changes detected. Applying $url in namespace $MANIFEST_NAMESPACE..."
        echo "$CONTENT" | kubectl apply -f - -n "$MANIFEST_NAMESPACE"
      fi
    else
      echo "$KIND $NAME does not exist in namespace $MANIFEST_NAMESPACE. Creating it..."
      echo "$CONTENT" | kubectl apply -f - -n "$MANIFEST_NAMESPACE"
    fi
  fi

  rm "$TMP_FILE"
}

process_files_recursively() {
  local repo_url=$1
  local manifest_dir=$2
  local dir_url="https://api.github.com/repos/$ORG/$REPO/contents/$manifest_dir"

  if [ -n "$GITHUB_TOKEN" ]; then
    API_RESPONSE=$(curl -sSL -H "Authorization: token $GITHUB_TOKEN" "$dir_url")
  else
    API_RESPONSE=$(curl -sSL "$dir_url")
  fi

  FILES=$(echo "$API_RESPONSE" | jq -r '.[] | select(.type == "file" and (.name | test("\\.yaml$"))) | .path')

  for file in $FILES; do
    apply_manifest "https://raw.githubusercontent.com/$ORG/$REPO/master" "$file"
  done

  SUBDIRS=$(echo "$API_RESPONSE" | jq -r '.[] | select(.type == "dir") | .path')

  for subdir in $SUBDIRS; do
    process_files_recursively "$repo_url" "$subdir"
  done
}

for REPO in "${REPOS[@]}"; do
  echo "Processing repository: $ORG/$REPO"
  process_files_recursively "$ORG/$REPO" "$MANIFEST_DIR"
done

echo "All manifests processed for all repositories."
