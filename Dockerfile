# Based on OSRM and VROOM Dockerfiles:
#  https://github.com/Project-OSRM/osrm-backend/blob/master/docker/Dockerfile-debian
#  https://github.com/VROOM-Project/vroom-docker/blob/master/Dockerfile

FROM debian:trixie-slim AS builder

#export DOCKER_DEFAULT_PLATFORM=linux/amd64
#FROM --platform=amd64 debian:trixie-slim AS builder
# test 32/64-bit: getconf LONG_BIT

# Let the container know that there is no TTY
ENV DEBIAN_FRONTEND=noninteractive

# see: https://github.com/Project-OSRM/osrm-backend-docker/blob/master/build.sh

# This can be a gitsha, tag, or branch - anything that works with `git checkout`
ARG OSRM_VERSION=v6.0.0

# This is passed to cmake for osrm-backend.  All other dependencies are built in
# release mode.
ARG BUILD_TYPE=Release
#ARG BUILD_TYPE=Debug

COPY . /src
WORKDIR /src


# Build OSRM:

RUN mkdir -p /src /opt && \
    apt-get update && \
    apt-get -y --no-install-recommends --no-install-suggests install \
        ca-certificates \
        cmake \
        g++ \
        gcc \
        git \
        libboost-all-dev \
        libbz2-dev \
        liblua5.4-dev \
        libtbb-dev \
        libxml2-dev \
        libzip-dev \
        lua5.4 \
        make \
        pkg-config \
        libsparsehash-dev libgdal-dev

RUN NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
    export CXXFLAGS="-Wno-array-bounds -Wno-uninitialized -Wno-stringop-overflow" && \
    echo "Building OSRM ${OSRM_VERSION}" &&\
    cd /src && \
    git -c advice.detachedHead=false clone https://github.com/Project-OSRM/osrm-backend.git && \
    cd osrm-backend && \
    git -c advice.detachedHead=false checkout ${OSRM_VERSION} && \
    mkdir build && \
    cd build && \
    cmake -DCMAKE_BUILD_TYPE=${BUILD_TYPE} -DENABLE_LTO=OFF .. && \
    make -j${NPROC} install && \
    cd ../profiles && \
    cp -r * /opt && \
    strip /usr/local/bin/*

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        expat \
        libboost-date-time1.83.0 \
        libboost-iostreams1.83.0 \
        libboost-program-options1.83.0 \
        libboost-thread1.83.0 \
        liblua5.4-0 \
        libtbb12 \
        vim-nox && \
# Add /usr/local/lib to ldconfig to allow loading libraries from there
    ldconfig /usr/local/lib


# Build VROOM:

RUN echo "Updating apt-get and installing dependencies..." && \
    apt-get -y update > /dev/null && apt-get -y install > /dev/null \
    git-core \
    build-essential \
    g++ \
    libssl-dev \
    libasio-dev \
    libglpk-dev \
    pkg-config


ARG VROOM_RELEASE=master

# to use the algorithm CH you have to prepare the data differently
# (replace osrm-partition and osrm-customize with a single osrm-contract)
RUN echo "Cloning vroom release/branch ${VROOM_RELEASE}..." && \
    git clone --branch $VROOM_RELEASE --single-branch --recurse-submodules https://github.com/VROOM-Project/vroom.git && \
    echo "Building VROOM ${VROOM_RELEASE} with $(nproc) cpus" && \
    cd /src/vroom/src && \
    make -j$(nproc) && \
    cd .. && \
    install -s bin/vroom /usr/local/bin/vroom-ch && \
    echo "Patching VROOM to use MLD instead of CH" && \
    patch -d /src/vroom -p1 < /src/vroom-MLD-patch.diff && \
    echo "Building VROOM ${VROOM_RELEASE} with $(nproc) cpus" && \
    cd /src/vroom/src && \
    make -j$(nproc) && \
    cd .. && \
    install -s bin/vroom /usr/local/bin/vroom-mld


ARG VROOM_EXPRESS_RELEASE=master

# clone here, since the runner image doesn't have git installed
RUN echo "Cloning and installing vroom-express release/branch ${VROOM_EXPRESS_RELEASE}..." && \
    git clone --branch $VROOM_EXPRESS_RELEASE --single-branch https://github.com/VROOM-Project/vroom-express.git


# Multistage build to reduce image size - https://docs.docker.com/build/building/multi-stage/#use-multi-stage-builds
# Only the content below ends up in the image, this helps remove /src from the image (which is large)
FROM debian:trixie-slim AS runstage

# Let the container know that there is no TTY
ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        curl \
        libexpat1 \
        libssl3 \
        libboost-date-time1.83.0 \
        libboost-filesystem1.83.0 \
        libboost-iostreams1.83.0 \
        libboost-thread1.83.0 \
        libboost-program-options1.83.0 \
        libglpk40 \
        liblua5.4-0 \
        libtbb12 \
        osmium-tool \
        less \
        vim-nox && \
# Add /usr/local/lib to ldconfig to allow loading libraries from there
    ldconfig /usr/local/lib

RUN /usr/sbin/useradd osrm -m -s /bin/bash

# now copy everything to the final image
COPY . /src

COPY --from=builder /src/vroom-express /src/vroom-express
COPY --from=builder /usr/local/bin /usr/local/bin
COPY --from=builder /usr/local/lib /usr/local/lib
COPY --from=builder /usr/local/share /usr/local/share
COPY --from=builder /opt /opt

# Quick tests:
RUN /usr/local/bin/osrm-extract --help && \
    /usr/local/bin/osrm-routed --help && \
    /usr/local/bin/osrm-contract --help && \
    /usr/local/bin/osrm-partition --help && \
    /usr/local/bin/osrm-customize --help && \
    /usr/bin/osmium --help

# osrm-routed
EXPOSE 5000


WORKDIR /src/vroom-express

RUN apt-get update > /dev/null && \
    apt-get install -y --no-install-recommends --no-install-suggests \
        libssl3 \
        curl \
        libglpk40 \
        npm \
        > /dev/null && \
    # Install vroom-express
    npm config set loglevel error && \
    npm install && \
    # To share the config.yml & access.log file with the host
    mkdir /conf


# leave docker-entrypoint.sh in /conf so that we can modify it w/o building a new container
#COPY ./docker-entrypoint.sh /src/docker-entrypoint.sh

ENV    VROOM_LOG=/conf VROOM_ROUTER=libosrm

#HEALTHCHECK --start-period=10s CMD curl --fail -s http://localhost:3000/health || exit 1

EXPOSE 3000

WORKDIR /data

# we will listen on a port for incoming vroom requests:
RUN apt-get install -y --no-install-recommends --no-install-suggests openbsd-inetd

# clean up a little
RUN rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/bin/bash"]
CMD ["/conf/docker-entrypoint.sh"]
