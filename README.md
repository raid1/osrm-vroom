# osrm-vroom
Combination of OSRM and Vroom in one dockerimage

There is a docker image for OSRM and there is a docker image for Vroom.
Vroom can send requests to OSRM through http but the usage of libosrm would be a lot faster.

This Dockerfile combines the two tools and sets them up to be able to use libosrm.

It is based on the OSRM and VROOM Dockerfiles:
 * https://github.com/Project-OSRM/osrm-backend/blob/master/docker/Dockerfile-debian
 * https://raw.githubusercontent.com/VROOM-Project/vroom-docker/refs/heads/master/Dockerfile


Build the container:
$ docker build -t osrm-vroom .

Run the container:
$ docker run --ulimit memlock=8589934592:8589934592 --shm-size="4g" --sysctl=kernel.shmmax=4294967296 -p 3000:3000 -p 5000:5000 --rm --name my_osrm-vroom -v "$PWD/maps:/data" -v "$PWD/conf:/conf" osrm-vroom

Test VROOM with libosrm:
$ docker exec -it my_osrm-vroom vroom --router libosrm -i /src/test.json

Useful to read:
* https://github.com/Project-OSRM/osrm-backend/wiki/Configuring-and-using-Shared-Memory
* https://datawookie.dev/blog/2019/07/using-shared-memory-with-osrm/

