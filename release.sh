#!/bin/bash
#
# Test Betelgeuse for sanity. If all is well, generate a new commit, tag it, and
# print instructions for further steps to take.
#
# NOTE: This script should be run from the repository root directory. Also in
# order to actually release to PyPI a proper `.pypirc` file should be already
# setup, for more information check
# https://docs.python.org/3/distutils/packageindex.html#the-pypirc-file
#
set -euo pipefail

# Make sure local fork is updated
git fetch -p --all
git checkout master
git merge --ff-only upstream/master

OLD_VERSION="$(git tag --list | sort -V | tail -n 1)"
MAJOR_VERSION="$(echo ${OLD_VERSION} | cut -d . -f 1)"
MINOR_VERSION="$(echo ${OLD_VERSION} | cut -d . -f 2)"
NEW_VERSION="${MAJOR_VERSION}.$((${MINOR_VERSION} + 1)).0"

# Bump version number
echo "${NEW_VERSION}" > VERSION

# Generate the package
make package-clean package

# Sanity check Betelgeuse packages on Python 2
venv="$(mktemp --directory)"
virtualenv -p python2 "${venv}"
set +u
source "${venv}/bin/activate"
set -u
for dist in dist/*; do
    ls "${dist}"
    pip install --quiet -U pip
    pip install --quiet git+https://github.com/elyezer/fake_pylarion.git
    pip install --quiet "${dist}"
    python -c "import betelgeuse" 1>/dev/null
    make test
    pip uninstall --quiet --yes betelgeuse
done
set +u
deactivate
set -u
rm -rf "${venv}"

# Get the changes from last release and commit
git add VERSION
git commit -m "Release version ${NEW_VERSION}" \
    -m "Shortlog of commits since last release:" \
    -m "$(git shortlog ${OLD_VERSION}.. | sed 's/^./    &/')"

# Tag with the new version
git tag "${NEW_VERSION}"

fmt <<EOF

This script has made only local changes: it has updated the VERSION file,
generated a new commit, tagged the new commit, and performed a few checks along
the way. If you are confident in these changes, you can publish them with
commands like the following:
EOF

cat <<EOF

    git push --tags origin master && git push --tags upstream master
    make publish

EOF
