FROM azul/zulu-openjdk-alpine:17-jre

LABEL org.opencontainers.image.source="https://github.com/josxha/minecraft-paper-docker" \
      org.opencontainers.image.authors="https://github.com/josxha" \
      org.opencontainers.image.url="https://hub.docker.com/r/josxha/minecraft-paper" \
      org.opencontainers.image.documentation="https://github.com/josxha/minecraft-paper-docker/blob/main/README.md" \
      org.opencontainers.image.title="Paper Minecraft" \
      org.opencontainers.image.description="Automatic Docker builds for Paper Minecraft"

# server jar
COPY paper.jar /minecraft/
# entrypoint
COPY entrypoint.sh /minecraft/
RUN chmod +x /minecraft/entrypoint.sh
# healthcheck
COPY healthcheck.sh /minecraft/
RUN chmod +x /minecraft/healthcheck.sh

VOLUME "/data"
WORKDIR "/data"

EXPOSE 25565/tcp
EXPOSE 25565/udp

ENV RAM=2G
ENV TZ=Europe/London
ENV JAVAFLAGS="-XX:+UseG1GC -XX:+ParallelRefProcEnabled -XX:MaxGCPauseMillis=200 -XX:+UnlockExperimentalVMOptions -XX:+DisableExplicitGC -XX:+AlwaysPreTouch -XX:G1NewSizePercent=30 -XX:G1MaxNewSizePercent=40 -XX:G1HeapRegionSize=8M -XX:G1ReservePercent=20 -XX:G1HeapWastePercent=5 -XX:G1MixedGCCountTarget=4 -XX:InitiatingHeapOccupancyPercent=15 -XX:G1MixedGCLiveThresholdPercent=90 -XX:G1RSetUpdatingPauseTimePercent=5 -XX:SurvivorRatio=32 -XX:+PerfDisableSharedMem -XX:MaxTenuringThreshold=1 -Dusing.aikars.flags=mcflags.emc.gs -Dcom.mojang.eula.agree=true"

HEALTHCHECK --interval=1m --timeout=3s \
  CMD /minecraft/healthcheck.sh

ENTRYPOINT ["/minecraft/entrypoint.sh"]