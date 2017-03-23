#! /bin/bash

set +o errexit
set +o nounset
set +o

# confirm our tap is set up
brew update
brew install --verbose jq
brew tap "${TRAVIS_REPO_SLUG}"

# now actually build some bottles
#
# for reference, see:
# * https://github.com/staticfloat/julia-buildbot/blob/master/commands/build_bottle.sh
# * https://github.com/Malvineous/travis-homebrew-bottle/blob/master/.travis.yml

formulas="pcre2"

for formula in $formulas
do
  tapped_formula="${TRAVIS_REPO_SLUG}/${formula}"
  RB="./Formula/${formula}.rb"

  echo "Printing JSON of bottle info..."
  echo "==="
  brew info --json=v1 "$RB"
  echo "==="

  BOTTLE=$(brew info --json=v1 "$RB" | jq '.[0].bottle')

  if [[ "$BOTTLE" == "{}" ]]
  then
    echo "No bottles for ${formula} are configured for downloading"

    brew unlink "$tapped_formula" || echo "Could not unlink."
    brew remove --force "$tapped_formula" || echo "Could not remove."

    echo "Building a new bottle for ${formula}..."
    brew install --verbose --build-bottle "$tapped_formula"
    brew bottle --verbose "$tapped_formula"

    # TODO: collect version attributes incl. SHA for each bottle
  fi
done

echo "Creating a Bintray descriptor file for the bottles to deploy..."
#DATE="$(date +%Y-%m-%d)"
COMMIT="$(git rev-parse --verify 'HEAD^{commit}')"
JSON="{
  \"package\": {
    \"subject\": \"killerswan\",
    \"repo\": \"bottles\",
    \"name\": \"all\"
  },
  \"version\": {
    \"name\": \"$COMMIT\"
  },
  \"files\": [{
    \"includePattern\": \"\\\\/Users\\\\/travis\\\\/build\\\\/killerswan\\\\/homebrew-pony\\\\/(.*.bottle.*.tar.gz)\",
    \"uploadPattern\": \"\$1\"
  }],
  \"publish\": true
}"

echo "Writing JSON to file..."
echo "$JSON" > "./bottles-to-deploy.json"
echo "=== WRITTEN FILE =========================="
cat -v "./bottles-to-deploy.json"
echo "==========================================="
