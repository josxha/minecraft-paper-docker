#!/usr/bin/env bash

readonly PAPER_API=https://papermc.io/api/v2/projects/paper
readonly DOCKER_TAG_API=https://hub.docker.com/v2/repositories/josxha/minecraft-paper/tags/

minecraftVersions=$(curl -s ${PAPER_API} | jq -r '.versions[]')
latestMinecraftVersion=${minecraftVersions[-1]}

dockerImageTags=$(curl -s ${DOCKER_TAG_API} | jq -c '.results[]' | xargs -0 -n1 echo | jq -r '.name')

for minecraftVersion in minecraftVersions; do
  echo "Check for Minecraft version ${minecraftVersion}"

  # get paper build ids for the minecraft version
  paperBuilds=$(curl -s ${PAPER_API}/versions/${minecraftVersion} | jq -r '.builds[]')
  latestPaperBuild=${paperBuilds[-1]}

  typeset -i amountPaperBuilds=${!paperBuilds[@]};
  for (( i = $amountPaperBuilds; i >= 0; i-- )); do
    paperBuild=${amountPaperBuilds[i]}
    echo "[$minecraftVersion] Check if an docker image exists for the paper build $paperBuild..."

    if [[ " ${dockerImageTags[*]} " =~ ${minecraftVersion}-${paperBuild} ]] && [[ $1 != 'force' ]]; then
        # image already exists
        echo Image ${minecraftVersion}-${paperBuild} exists.
        continue
    fi

    # image doesn't exist yet
    # download paper build
    jarName=$(curl -s ${PAPER_API}/versions/${latestMinecraftVersion}/builds/${latestPaperBuild} | jq -r '.downloads.application.name')
    curl -s -o paper.jar ${PAPER_API}/versions/${latestMinecraftVersion}/builds/${latestPaperBuild}/downloads/${jarName}

    # build and push image
    if [[ "$minecraftVersion" == "$latestMinecraftVersion" ]]; then
      if [[ "$paperBuilds" == "$latestPaperBuild" ]]; then
        # latest minecraft version, latest paper build
        docker build . \
          --tag josxha/minecraft-paper:$minecraftVersion-$paperBuild \
          --tag josxha/minecraft-paper:$minecraftVersion \
          --tag josxha/minecraft-paper:latest
      else
        # latest minecraft version, not latest paper build
        docker build . \
          --tag josxha/minecraft-paper:$minecraftVersion-$paperBuild
      fi
    else
      if [[ "$paperBuilds" == "$latestPaperBuild" ]]; then
        # not latest minecraft version, latest paper build
        docker build . \
          --tag josxha/minecraft-paper:$minecraftVersion-$paperBuild \
          --tag josxha/minecraft-paper:$minecraftVersion
      else
        # not latest minecraft version, not latest paper build
        docker build . \
          --tag josxha/minecraft-paper:$minecraftVersion-$paperBuild
      fi
    fi
  done
done