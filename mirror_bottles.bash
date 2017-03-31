#! /bin/bash

set -o errexit
set -o nounset

FORMULAS="$1"

# we want to mirror bottles from core to pony (where core can't deprecate them)
CORE_ROOT="https://homebrew.bintray.com/bottles"
PONY_ROOT="https://dl.bintray.com/killerswan/bottles"
BINTRAY_USER="killerswan"
BINTRAY_REPO="bottles"
BINTRAY_PACKAGE="all"
LOCAL_DIR_PATTERN="/Users/travis/build/killerswan/homebrew-pony"
# TODO: try substituting "."

function has_sha256 {
  # Given a SHA256 and a file name, check it.
  #
  # I can't believe shasum is missing an argument for this.
  sha256="$1"
  filepath="$2"

  checksums=$(mktemp)
  echo "$sha256  $filepath" > "$checksums"
  shasum --check "$checksums"
}

function is_bottle_mirrored() {
  # Given a bottle's root_url and url, check if we have mirrored it yet.
  root="$1"
  url="$2"
  
  # check if the mirror's bottle exists
  mirror_url="${url/$root/$PONY_ROOT}"
  status="$(curl --silent --head --output /dev/null --write-out "%{http_code}" --location "$mirror_url")"

  # return the test for HTTP 200 OK
  [[ "$status" == "200" ]]
}

function download_and_check_bottle() {
  local_name="$1"
  url="$2"
  sha256="$3"

  # download the bottle to a file
  curl -o "$local_name" --silent --location "$url"

  # check its SHA
  has_sha256 "$sha256" "$local_name"
}

write_bintray_descriptor() {
  # Given a formula label and a list of bottle file name,
  # save out a bintray deployment descriptor JSON file.
  formula_name="$1"
  len_bottles="$2"
  bottle_files_to_deploy="$3"

  echo "Creating a Bintray descriptor file for the bottles to deploy..."
  json_name="${formula_name}.bintray.json"

  commit="$(git rev-parse --verify 'HEAD^{commit}')"

  # everything before the individual file objects...
  start="{
    \"package\": {
      \"subject\": \"$BINTRAY_USER\",
      \"repo\":    \"$BINTRAY_REPO\",
      \"name\":    \"$BINTRAY_PACKAGE\"
    },
    \"version\": {
      \"name\": \"${commit}\"
    },
    \"publish\": true,
    \"files\": ["

  # closing braces for everything but the file objects
  end="]}"
  
  echo "Writing JSON to ${json_name}..."
  echo "$start" > "$json_name"

  for (( ii=0; ii<len_bottles; ii++ ))
  do
    bottle_file="${bottle_files_to_deploy[$ii]}"
    echo "Writing section for file $bottle_file..."
    # the individual file objects...
    file_section="{
        \"includePattern\": \"$LOCAL_DIR_PATTERN/($bottle_file)\",
        \"uploadPattern\": \"\$1\"
      }"
    # note that this does not allow overwriting: we need another property to allow that

    echo "$file_section" >> "$json_name"

    # write commas between file objects
    # (but not trailing the last one)
    if (( ii < len_bottles - 1 ))
    then
      echo "," >> "$json_name"
    fi
  done

  echo "$end" >> "$json_name"
  echo "Writing done."

  echo "$json_name contains:"
  # run it through jq to validate the JSON too because who knows what Bintray will do
  jq '.' "$json_name"
}

function copy_bottles_from_core() {
  formula="$1"

  # find the actual Ruby formula
  script="./Formula/${formula}.rb"

  # properties for all bottles in the formula
  info="$(brew info --json=v1 "$script")"
  root="$(echo "$info" | jq --raw-output '.[0].bottle.stable.root_url')"

  # so we can enumerate each bottle
  bottles="$(echo "$info" | jq '.[0].bottle.stable.files')"
  len_bottles="$(echo "$bottles" | jq 'length')"
  oses="$(echo "$bottles" | jq 'keys')"

  # names of bottle files we'll deploy to bintray
  bottle_files_to_deploy_count=0
  bottle_files_to_deploy=()

  for (( ii=0; ii<len_bottles; ii++ ))
  do
    # properties for this one bottle
    os="$(echo "$oses" | jq --raw-output ".[$ii]")"
    url="$(echo "$bottles" | jq --raw-output ".[\"$os\"].url")"
    sha256="$(echo "$bottles" | jq --raw-output ".[\"$os\"].sha256")"

    # expected bottle URLs
    core_bottle_url="${url/$root/$CORE_ROOT}"
    mirrored_bottle_url="${url/$root/$PONY_ROOT}"
    bottle_name="$(basename "$url")"

    echo "Mirroring $bottle_name"
    echo "from $core_bottle_url"
    echo "to $mirrored_bottle_url"
    echo "with SHA $sha256..."

    # check for mirroring
    if is_bottle_mirrored "$root" "$url"
    then
      echo "The bottle is already mirrored."

      # if we were to download it and check the signature:
      #download_and_check_bottle "$(mktemp)" "$mirrored_bottle_url" "$sha256"
    else
      # try downloading the homebrew-core bottle and check its SHA
      if download_and_check_bottle "$bottle_name" "$core_bottle_url" "$sha256"
      then
        echo "Downloaded the bottle, now preparing to mirror..."
        bottle_files_to_deploy_count=$((bottle_files_to_deploy_count + 1))
        bottle_files_to_deploy+=("$bottle_name")
      else
        echo "WARNING!! Error downloading the bottle from core!"
        return 1
      fi
    fi
  done

  # get ready to deploy what we've downloaded
  if (( bottle_files_to_deploy_count > 0 ))
  then
    write_bintray_descriptor "$formula" "$len_bottles" "${bottle_files_to_deploy[@]}"
  else
    echo "For $formula, all bottles have been mirrored: done."
  fi
}

for formula in $FORMULAS
do
  copy_bottles_from_core "$formula"
done
