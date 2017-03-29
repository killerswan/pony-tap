#! /bin/bash

set -o errexit
set -o nounset

FORMULAS="$1"

# we want to mirror bottles from core to pony (where core can't deprecate them)
CORE_ROOT="https://homebrew.bintray.com/bottles"
PONY_ROOT="https://dl.bintray.com/killerswan/bottles"

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

function is_bottle_mirror_correct() {
  # Given a bottle's root_url, url, and checksum, see if we have mirrored it correctly (by SHA).
  root="$1"
  url="$2"
  sha256="$3"
  
  mirror_url="${url/$root/$PONY_ROOT}"

  bottle_name=$(mktemp)
  curl -o "$bottle_name" --silent --location "${mirror_url}"

  # check its SHA
  has_sha256 "$sha256" "$bottle_name"
}

function is_bottle_mirrored() {
  # Given a bottle's root_url and url, check if we have mirrored it yet.
  root="$1"
  url="$2"
  
  mirror_url="${url/$root/$PONY_ROOT}"
  status="$(curl --silent --head --output /dev/null --write-out "%{http_code}" --location "${mirror_url}")"

  # return the test for HTTP 200 OK
  [[ "$status" == "200" ]]
}

function copy_bottles_from_core() {
  script="$1"

  info="$(brew info --json=v1 "$script")"
  root="$(echo "$info" | jq --raw-output '.[0].bottle.stable.root_url')"

  bottles="$(echo "$info" | jq '.[0].bottle.stable.files')"
  len_bottles="$(echo "$bottles" | jq 'length')"
  oses="$(echo "$bottles" | jq 'keys')"

  for (( ii=0; ii<len_bottles; ii++ ))
  do
    os="$(echo "$oses" | jq --raw-output ".[$ii]")"
    url="$(echo "$bottles" | jq --raw-output ".[\"$os\"].url")"
    sha256="$(echo "$bottles" | jq --raw-output ".[\"$os\"].sha256")"

    if ! is_bottle_mirrored "$root" "$url"
    then
      echo "We need to mirror the bottle at $url."
      # PENDING
    else
      if ! is_bottle_mirror_correct "$root" "$url" "$sha256"
      then
        echo "WARNING!! The bottle $url is mirrored, but does not match $sha256.  Something is wrong!"
        # PENDING
      else
        echo "OK already! The bottle $url is mirrored with SHA $sha256."
      fi
    fi
  done
}

for formula in $FORMULAS
do
  script="./Formula/${formula}.rb"

  copy_bottles_from_core "$script"

  # PENDING: for this formula, write a bintray JSON
done
