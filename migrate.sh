#!/bin/bash
# Migration script:
# 1. Rename MuterTests/ -> LoooprTests/
# 2. Move website/ to a separate sibling repo at ~/Developer/looopr-website
# 3. Re-run xcodegen so the project.yml changes take effect

set -e
cd "$(dirname "$0")"

echo "[1/4] Renaming MuterTests/ -> LoooprTests/"
if [ -d "MuterTests" ]; then
  git mv MuterTests LoooprTests
  echo "  done"
else
  echo "  MuterTests/ already renamed or missing — skipping"
fi

echo ""
echo "[2/4] Extracting website/ to ~/Developer/looopr-website"
WEBSITE_DEST="$HOME/Developer/looopr-website"
if [ -d "website" ]; then
  if [ -e "$WEBSITE_DEST" ]; then
    echo "  ERROR: $WEBSITE_DEST already exists. Move or delete it, then re-run."
    exit 1
  fi
  mkdir -p "$HOME/Developer"
  cp -R website "$WEBSITE_DEST"
  cd "$WEBSITE_DEST"
  git init -q
  git add -A
  git commit -q -m "Initial commit: Looopr marketing website"
  cd - > /dev/null
  git rm -rf website
  echo "  Website copied to $WEBSITE_DEST and initialized as a git repo"
  echo "  Removed website/ from the iOS repo"
else
  echo "  website/ already moved or missing — skipping"
fi

echo ""
echo "[3/4] Re-running xcodegen"
if command -v xcodegen > /dev/null 2>&1; then
  xcodegen generate
  echo "  done"
else
  echo "  WARNING: xcodegen not installed. Install with: brew install xcodegen"
fi

echo ""
echo "[4/4] Final state"
echo "--- Top-level contents ---"
ls -la
echo ""
echo "--- Git status ---"
git status --short
echo ""
echo "Done. Next steps:"
echo "  git add -A"
echo "  git commit -m \"Rename tests, extract website, fix orientation\""
