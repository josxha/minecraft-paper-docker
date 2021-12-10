#!/bin/sh
set -e
exec java -jar -Xms$RAM -Xmx$RAM $JAVAFLAGS /usr/bin/paper.jar --nojline nogui