#!/bin/bash

# Call this from the root directory of the package. E.g. if the code is in
# /home/user/src/gps_history_release, call:
# > cd /home/user/src/gps_history_release
# > tool/prep_release.sh
set -e

# Requires: git, dart, dartdoc, github CLI

git pull

# Update any dependencies
dart pub update

# See if the analyzer doesn't find anything
dart analyze
status=$?
# If analyze found issues, stop
[ $status -ne 0 ] && read -p 'dart anlyze found problems. Fix before releasing. Press ENTER.' && exit $status

# See if the documentation is in order
rm -rf doc/api
dart doc
status=$?
[ $status -ne 0 ] && read -p 'dart doc found problems. Fix before releasing. Press ENTER.' $$ exit $status

read -p 'Inspect dart doc output for warnings/errors. Press ENTER if OK to continue.'

rm -rf doc/api

# Do a dryrun
dart pub publish --dry-run
read -p 'Release name (e.g. 1.0.2): ' relname
read -p 'Preparing to release '$relname' on GitHub. Press ENTER to continue.'

# Generate the github changes file.
tool/gen_github_changes.py CHANGELOG.md github_changes.md $relname
# Release and remember tatus.
gh release create $relname -F github_changes.md
status=$?
# Remove the github changes file.
rm -f github_changes.md

# Publish to pub.dev
read -p 'Preparing to publish '$relname' on pub.dev. Press ENTER to continue.'
dart pub publish