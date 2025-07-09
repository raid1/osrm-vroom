#!/usr/bin/env bash

set -x
osrm-datastore --dataset-name car-mld /data/mld/oberbayern-latest.osrm
osrm-datastore --dataset-name car-ch /data/ch/oberbayern-latest.osrm
osrm-datastore --list
ipcs -lm
ipcs -m

# start the OSRM daemon on port 5000
#/usr/local/bin/osrm-routed --algorithm mld /data/oberbayern-latest.osrm &
# or using shared memory:
/usr/local/bin/osrm-routed --shared-memory --algorithm mld --dataset-name=car-mld &
#/usr/local/bin/osrm-routed --shared-memory --algorithm ch --dataset-name=car-ch &
set +x

ln -s /usr/local/bin/vroom-mld /usr/local/bin/vroom
#ln -s /usr/local/bin/vroom-ch /usr/local/bin/vroom

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

#cd /src/vroom-express && VROOM_ROUTER=${VROOM_ROUTER} VROOM_LOG=${VROOM_LOG} exec npm start
#sleep 20000


update-inetd --group VROOM --add '30000\t\tstream\ttcp\tnowait\troot\t/usr/local/bin/vroom-ch --router libosrm'
update-inetd --group VROOM --add '30001\t\tstream\ttcp\tnowait\troot\t/usr/local/bin/vroom-mld --router libosrm'

# start inetd in foreground
/usr/sbin/inetd -i
