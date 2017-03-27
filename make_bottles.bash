#! /bin/bash

set -o errexit
set -o nounset

# confirm our tap is set up
brew update
brew install --verbose jq
brew tap "${TRAVIS_REPO_SLUG}"

name_from_printout() {
  # Given a printout from 'brew bottle', find the bottle file name.
  printout="$1"

  grep -i "==> Bottling" "${printout}" | sed -e "s/^==> Bottling //" -e "s/...$//"
}

snippet_from_printout() {
  # Given a printout from 'brew bottle', find the section describing a Formula update.
  printout="$1"

  bottle_name="$(name_from_printout "${printout}")"

  start_section="$(grep -n "./${bottle_name}" "${printout}" | sed -e "s/:.*//")"
  length="$(wc -l "${printout}" | sed -e "s/^ *//" -e "s/ .*//")"
  section_length=$((1 + $length - $start_section))

  tail -${section_length} "${printout}"
}

save_formula_snippet() {
  # Given a printout from 'brew bottle', save the formula change suggested.
  # This has no file type, but is a snippet of Homebrew DSL in Ruby.
  printout="$1"
  bottle_name="$2"

  snippet_name="${bottle_name}.snippet.txt"

  echo "Writing Ruby snippet from the 'brew bottle' output to ${snippet_name}..."
  echo "$(snippet_from_printout "${printout}")" > "${snippet_name}"
}

fail_if_bintray_has() {
  # Given a bottle name, check our Bintray for previous uploads with the same name
  bottle_name="$1"

  url="https://dl.bintray.com/killerswan/bottles/${bottle_name}"
  code="$(curl --silent --head --output /dev/null --write-out "%{http_code}" --location "${url}")"

  if [[ "$code" == "200" ]]
  then
    echo "A bottle with this name is already deployed to Bintray.  Exiting."
    exit 1
  else
    echo "This seems to be a new bottle."
  fi
}

write_bintray_descriptor() {
  # Given a formula label and a bottle file name,
  # save out a bintray deployment descriptor JSON file.
  #
  # The benefit of doing this per-file is that we can detect duplicate versions.
  formula_name="$1"
  bottle_name="$2"

  echo "Creating a Bintray descriptor file for the bottles to deploy..."
  JSON_NAME="${formula_name}.bintray.json"

  JSON="{
  \"package\": {
    \"subject\": \"killerswan\",
    \"repo\": \"bottles\",
    \"name\": \"all\"
  },
  \"version\": {
    \"name\": \"${bottle_name}\"
  },
  \"publish\": true,
  \"files\": [
    {
      \"includePattern\": \"/Users/travis/build/killerswan/homebrew-pony/(${bottle_name})\",
      \"uploadPattern\": \"\$1\"
    },
    {
      \"includePattern\": \"/Users/travis/build/killerswan/homebrew-pony/(${bottle_name}.snippet.txt)\",
      \"uploadPattern\": \"\$1\"
    }
  ]
}"

  # Note wildcard pattern:
  # { \"includePattern\": \"/Users/travis/build/killerswan/homebrew-pony/(.*.bottle.*.tar.gz)\", \"uploadPattern\": \"\$1\" },

  # Commit:
  #COMMIT="$(git rev-parse --verify 'HEAD^{commit}')"

  echo "Writing JSON to ${JSON_NAME}..."
  echo "$JSON" > "${JSON_NAME}"
}

# now actually build some bottles
#
# for reference, see:
# * https://github.com/staticfloat/julia-buildbot/blob/master/commands/build_bottle.sh
# * https://github.com/Malvineous/travis-homebrew-bottle/blob/master/.travis.yml

for formula in $FORMULAS
do
  tapped_formula="${TRAVIS_REPO_SLUG}/${formula}"
  RB="./Formula/${formula}.rb"

  echo "Printing JSON of bottle info..."
  echo "==="
  brew info --json=v1 "$RB"
  echo "==="

  BOTTLE=$(brew info --json=v1 "$RB" | jq '.[0].bottle')

  if [[ "$BOTTLE" != "{}" ]]
  then
    echo "Maybe nothing to do: a bottle was found for ${formula}"
  else
    echo "No bottles for ${formula} are configured for downloading"

    brew unlink "$tapped_formula" || echo "Could not unlink."
    brew remove --force "$tapped_formula" || echo "Could not remove."

    echo "Building a new bottle for ${formula}..."
    brew install --verbose --build-bottle "$tapped_formula"
    brew bottle --verbose "$tapped_formula" > "printout.txt"

    bottle_name="$(name_from_printout "printout.txt")"
    echo "Bottle file name is $bottle_name"

    echo "Checking for previous uploads..."
    fail_if_bintray_has "$bottle_name"

    echo "Saving the Ruby snippet from brew bottle..."
    save_formula_snippet "printout.txt" "${bottle_name}"

    echo "Saving the Bintray descriptor file..."
    write_bintray_descriptor "${formula}" "${bottle_name}"

    echo "Printout tail is..."
    echo "===="
    tail "printout.txt"
    echo "===="

    echo "Snippet is..."
    echo "===="
    cat -v "${bottle_name}.snippet.txt"
    echo "===="

    echo "Bintray desc. is..."
    echo "===="
    cat -v "${formula}.bintray.json"
    echo "===="
  fi
done
