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

write_bintray_desc_for_one() {
  # Given a formula label and a single bottle file name,
  # save out a bintray deployment descriptor JSON file.
  formula_name="$1"
  file_to_deploy="$2"
  suffix="$3"

  echo "Creating a Bintray descriptor file for the bottles to deploy..."
  json_name="${formula_name}${suffix}.bintray.json"

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
  
  # the individual file objects...
  file_section="{
    \"includePattern\": \"./($file_to_deploy)\",
    \"uploadPattern\": \"\$1\"
  }"
  # note that this does not allow overwriting: we need another property to allow that

  echo "Writing JSON to ${json_name}..."
  echo "$start" > "$json_name"
  echo "$file_section" >> "$json_name"
  echo "$end" >> "$json_name"
  echo "Writing done."

  echo "$json_name contains:"
  # run it through jq to validate the JSON too because who knows what Bintray will do
  jq '.' "$json_name"
}

write_bintray_desc_for_set() {
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
        \"includePattern\": \"./($bottle_file)\",
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

write_bintray_desc() {
  # Given a formula label and a list of bottle file name,
  # save out a bintray deployment descriptor JSON file.
  formula_name="$1"
  len_bottles="$2"
  bottle_files_to_deploy="$3"

  total_size_mb="$(du -mc "${bottle_files_to_deploy[@]}" | tail -1 | cut -f 1)"

  # Bintray has a limit of ??? (I thought 500 MB) per upload, so check how big our set is.
  if (( total_size_mb <= 500 ))
  then
    # If under the limit we can write one bintray descriptor file (easy YAML config).
    echo "Writing a single bintray desc file."
    write_bintray_desc_for_set "$formula" "$len_bottles" "${bottle_files_to_deploy[@]}"
  else
    # If over the limit (as LLVM 3.9 and 4 are), we may pass with one bintray desc per bottle,
    # like so, named, e.g. "llvm--1.bintray.json", "llvm--2.bintray.json", etc.
    #
    # This will require three (or more) deploy clauses, and have to be checked by hand.
    echo "WARNING WARNING WARNING WARNING"
    echo "Writing multiple bintray desc files for $formula_name, over the 500 MB limit."
    echo "WARNING WARNING WARNING WARNING"
    for (( jj=0; jj<len_bottles; jj++ ))
    do
      file_to_deploy="${bottle_files_to_deploy[jj]}"
      size_mb="$(du -mc "$file_to_deploy" | tail -1 | cut -f 1)"
      if (( size_mb <= 500 ))
      then
        write_bintray_desc_for_one "$formula_name" "$file_to_deploy" "--$jj"
      else
        echo "ERROR!! Cannot upload $file_to_deploy because $file_to_deploy is over 500 MB!!!"
        return 1
      fi
    done
  fi
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
        echo "ERROR!! Error downloading the bottle from core!"
        return 1
      fi
    fi
  done

  # get ready to deploy what we've downloaded
  if (( bottle_files_to_deploy_count > 0 ))
  then
    write_bintray_desc "$formula" "$len_bottles" "${bottle_files_to_deploy[@]}"
  else
    echo "For $formula, all bottles have been mirrored: done."
  fi
}

for formula in $FORMULAS
do
  copy_bottles_from_core "$formula"
done
