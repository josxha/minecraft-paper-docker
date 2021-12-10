#!/usr/bin/env bash

latestMinecraftVersion=$(curl -s https://papermc.io/api/v2/projects/paper | jq -r '.versions[]' | tail -n 1)

imageTags=$(curl -s https://hub.docker.com/v2/repositories/marctv/minecraft-papermc-server/tags/ | jq -c '.results[]' | xargs -0 -n1 echo | jq -r '.name')

# get paper build ids
latestPaperBuild=$(curl -s https://papermc.io/api/v2/projects/paper/versions/${latestMinecraftVersion} | jq -r '.builds[]' | tail -n 1)

jarName=$(curl -s https://papermc.io/api/v2/projects/paper/versions/${latestMinecraftVersion}/builds/${latestPaperBuild} | jq -r '.downloads.application.name')

if [[ " ${imageTags[*]} " =~ ${latestMinecraftVersion}-${latestPaperBuild} ]] && [[ $1 != 'force' ]]; then
  echo Already newest paper patch.
  exit 0
fi

# download paper build jar
curl -s -o paper.jar https://papermc.io/api/v2/projects/paper/versions/${latestMinecraftVersion}/builds/${latestPaperBuild}/downloads/${jarName}

# build and push images
docker build . --tag josxha/minecraft-paper:$latestMinecraftVersion-$latestPaperBuild --tag josxha/minecraft-paper:$latestMinecraftVersion
docker push josxha/minecraft-paper:$latestMinecraftVersion
docker push josxha/minecraft-paper:$latestMinecraftVersion-$latestPaperBuild