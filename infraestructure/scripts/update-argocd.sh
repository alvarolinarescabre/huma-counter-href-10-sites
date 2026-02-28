#!/usr/bin/env bash
set -euo pipefail

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "GITHUB_TOKEN not set. Will attempt unauthenticated or SSH clone."
fi
if [ -z "${ARGOCD_REPO:-}" ]; then
  echo "ARGOCD_REPO not set. Set ARGOCD_REPO like 'owner/repo'."
  exit 1
fi
if [ -z "${ARGOCD_APP_NAME:-}" ]; then
  echo "ARGOCD_APP_NAME not set."
  exit 1
fi

if [ $# -lt 1 ]; then
  echo "Usage: $0 <image-uri> [push-branch]"
  exit 1
fi

IMAGE_URI="$1"
PUSH_BRANCH_ARG="${2:-}"
PUSH_BRANCH="${ARGOCD_PUSH_BRANCH:-${PUSH_BRANCH_ARG:-main}}"

IMAGE_TAG="$(echo "$IMAGE_URI" | awk -F: '{print $NF}')"
IMAGE_NAME="$(echo "$IMAGE_URI" | sed 's/:.*$//')"

TMPDIR="$(mktemp -d)"
echo "Cloning $ARGOCD_REPO to $TMPDIR/argocd"
if [ -n "${GITHUB_TOKEN:-}" ]; then
  git clone "https://$GITHUB_TOKEN@github.com/$ARGOCD_REPO.git" "$TMPDIR/argocd"
else
  # Try HTTPS anonymous clone first
  if git clone "https://github.com/$ARGOCD_REPO.git" "$TMPDIR/argocd" 2>/dev/null; then
    echo "Cloned via anonymous HTTPS"
  else
    # Fall back to SSH (requires appropriate SSH key configured in environment)
    git clone "git@github.com:$ARGOCD_REPO.git" "$TMPDIR/argocd"
  fi
fi

TARGET_DIR="$TMPDIR/argocd/apps/$ARGOCD_APP_NAME"
mkdir -p "$TARGET_DIR"
echo "Copying k8s manifests into $TARGET_DIR/base"
rm -rf "$TARGET_DIR/base"
mkdir -p "$TARGET_DIR/base"
cp -r k8s/base/* "$TARGET_DIR/base/"

KUSTOMIZATION="$TARGET_DIR/base/kustomization.yaml"
if [ -f "$KUSTOMIZATION" ]; then
  echo "Updating kustomization with image name and tag"
  sed -i "s|name: .*|name: $IMAGE_NAME|" "$KUSTOMIZATION" || true
  sed -i "s|newTag: .*|newTag: $IMAGE_TAG|" "$KUSTOMIZATION" || true
fi

cd "$TMPDIR/argocd"
git config user.email "codebuild@local"
git config user.name "codebuild"

git add "apps/$ARGOCD_APP_NAME"
if git diff --staged --quiet; then
  echo "No changes to push"
  rm -rf "$TMPDIR"
  exit 0
fi
git commit -m "ci: update $ARGOCD_APP_NAME image to $IMAGE_TAG"
echo "Pushing to branch: $PUSH_BRANCH"
git push origin HEAD:$PUSH_BRANCH

echo "Pushed changes to $ARGOCD_REPO/apps/$ARGOCD_APP_NAME"
rm -rf "$TMPDIR"
