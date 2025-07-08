#!/usr/bin/env bash

osrm-datastore --dataset-name car /data/oberbayern-latest.osrm
osrm-datastore --list
ipcs -lm
ipcs -m

# start the OSRM daemon on port 5000
/usr/local/bin/osrm-routed --shared-memory --algorithm mld --dataset-name=car &

# copy the vroom config.yml to the host if it doesn't exist yet
# or copy it to the source if it does exist
if test -f /conf/config.yml; then
  cp /conf/config.yml /src/vroom-express/config.yml
else
  cp /src/vroom-express/config.yml /conf/config.yml
fi

# Create access.log if it doesn't exist
if ! test -f /conf/access.log; then
  touch /conf/access.log
fi

cd /src/vroom-express && VROOM_ROUTER=${VROOM_ROUTER} VROOM_LOG=${VROOM_LOG} exec npm start

