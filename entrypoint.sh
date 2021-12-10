#!/bin/sh
set -e
exec java -jar -Xms$RAM -Xmx$RAM $JAVAFLAGS /minecraft/paper.jar --nojline nogui