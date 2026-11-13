#!/bin/sh
# Schreibt die Commit-ID in die Info.plist der gebauten App (Schlüssel CueViewGitCommit).
# Uncommittete Änderungen werden mit "-dirty" markiert, damit Release-Pakete nachprüfbar bleiben.
set -e
PLIST="${TARGET_BUILD_DIR}/${INFOPLIST_PATH}"
COMMIT=$(git -C "${SRCROOT}" rev-parse --short=7 HEAD 2>/dev/null || echo unknown)
if [ "$COMMIT" != unknown ] && [ -n "$(git -C "${SRCROOT}" status --porcelain --untracked-files=no 2>/dev/null)" ]; then
  COMMIT="${COMMIT}-dirty"
fi
/usr/libexec/PlistBuddy -c "Delete :CueViewGitCommit" "$PLIST" 2>/dev/null || true
/usr/libexec/PlistBuddy -c "Add :CueViewGitCommit string ${COMMIT}" "$PLIST"
echo "CueViewGitCommit = ${COMMIT}"
