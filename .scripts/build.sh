#!/usr/bin/env bash
set -e
archs="${ARCHS}"
buildimage_version='6.4'

for addon in "$@"; do

  if [[ "$(jq -r '.image' ${addon}/config.json)" == 'null' ]]; then
    echo "No build image set for ${addon}. Skip build!"
    exit 0
  fi
  
if [[ "$TRAVIS_EVENT_TYPE" == 'pull_request' ]]; then
  changed_files=$(git diff --name-only --oneline "${TRAVIS_COMMIT_RANGE}" -- "${addon}"/ | cat)
elif [[ "$TRAVIS_EVENT_TYPE" == 'push' ]]; then
  git remote set-branches --add origin master
  git fetch
  TRAVIS_COMMIT_RANGE="origin/master...$TRAVIS_COMMIT"
  changed_files=$(git diff --name-only --oneline "${TRAVIS_COMMIT_RANGE}" -- "${addon}"/ | cat)
fi

  echo "Changed files in ${TRAVIS_COMMIT_RANGE} for ${addon}:"
  echo "${changed_files}"

  if { [ -z ${TRAVIS_COMMIT_RANGE} ] || [ ! -z "$changed_files" ]; } || [[ "$FORCE_PUSH" = "true" ]]; then
    if [ -z "$archs" ]; then
      archs=$(jq -r '.arch // ["armv7", "armhf", "amd64", "aarch64", "i386"] | [.[] | "--" + .] | join(" ")' ${addon}/config.json)
    fi
     
    echo "Building archs: ${archs}"
    docker run --rm --privileged -v '/var/run/docker.sock:/var/run/docker.sock' -v "$(pwd)/${addon}:/data" \
      "homeassistant/amd64-builder:${buildimage_version}" ${archs} -t /data --test --no-latest

    # Optimize every arch image
    for arch in ${archs}; do
      image_name=${image_template/\{arch\}/$arch}

      echo "Optimize $image_name"

      echo "Setup inspection env"
      docker run --rm --privileged multiarch/qemu-user-static --reset -p yes

      mappings="$(jq -r '.map // [] | map("/" + .) | join(" ")' "${addon}/config.json") /data"
      mapping_cmd=''
      for mapping in ${mappings}; do
        echo "Create mapping folder $mapping"
        mkdir "$(pwd)${mapping}"
        mapping_cmd="${mapping_cmd} --mount $(pwd)${mapping}:${mapping}"
      done

      config=$(jq -r '.options // {}' "${addon}/config.json")
      echo "$config" > "$(pwd)/data/options.json"

      exposed_ports=$(jq -r '.ports // {} | keys | [.[]] | map(split("/")[0] | "--expose " + .) | join(" ")' "${addon}/config.json")
      probe_path=$(jq -r '.ingress_entry // "" | "--http-probe-cmd /" + .' "${addon}/config.json")

      echo "Slim image"
      docker-slim build --remove-file-artifacts --continue-after probe --show-clogs --show-blogs \
        ${exposed_ports} ${probe_path} ${mapping_cmd} \
        $image_name:$plugin_version
      docker rmi "$image_name:$plugin_version"
      docker tag "$image_name.slim:$plugin_version" "$image_name:$plugin_version"

      echo "Create latest from $plugin_version"
      docker tag "$image_name:$plugin_version" "$image_name:latest"
    done

  else
    echo "No change for ${addon}"
  fi
done
