#!/bin/sh
# Link Linux-compiled node_modules into the working directory
# (the anonymous volume shadows the host's macOS-compiled node_modules)
if [ -d /opt/nanoclaw-deps/node_modules ] && [ ! -d node_modules/.bin ]; then
  ln -sf /opt/nanoclaw-deps/node_modules/* node_modules/
  ln -sf /opt/nanoclaw-deps/node_modules/.bin node_modules/.bin
  ln -sf /opt/nanoclaw-deps/node_modules/.package-lock.json node_modules/.package-lock.json
fi
exec "$@"
