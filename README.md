# Automatic Docker builds for Paper Minecraft

This repository checks automatically every hour for new paper server builds, builds new images with them and uploads them to the docker registry.

## Links
- Images: [hub.docker.com/r/josxha/minecraft-paper](https://hub.docker.com/r/josxha/minecraft-paper)
- Repo: [github.com/josxha/Docker-Minecraft-PaperMC-Server](https://github.com/josxha/Docker-Minecraft-PaperMC-Server)
- Papermc: [papermc.io/downloads](https://papermc.io/downloads)

## Why to use this image
- [x] Easy to use and configure
- [x] Up to date with the latest paper builds
- [x] Much smaller image size compared to other paper images
- [x] Open source repository

## Get Started
1. Install docker ([docker docs](https://docs.docker.com/get-docker/))
2. Install docker-compose ([docker docs](https://docs.docker.com/compose/install/))
3. Example content of your `docker-compose.yml` file:
```yaml
version: '3'
services:
    minecraft:
        image: josxha/minecraft-paper:latest # or e.g. 1.18.1
        container_name: minecraft
        restart: unless-stopped
        ports:
            - 0.0.0.0:25565:25565
        volumes:
            - ./data:/data:rw
        environment:
            - TZ=Europe/London
            - RAM=4G
```
4. Run `docker-compose up -d` in the directory of your `docker-compose.yml` file.
5. (optional) Use [watchtower](https://hub.docker.com/r/containrrr/watchtower) to keep your container up to date with the latest image build automatically.

## To Do
- build new image if there is a new openjdk patch
- don't run the server as root
- build images for old minecraft versions