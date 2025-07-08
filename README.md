# osrm-vroom
Combination of OSRM and Vroom in one dockerimage

There is a docker image for OSRM and there is a docker image for Vroom.
Vroom can send requests to OSRM through http but the usage of libosrm would be a lot faster.

This Dockerfile combines the two tools and sets them up to be able to use libosrm.
