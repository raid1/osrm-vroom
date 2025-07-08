# Based on OSRM and VROOM Dockerfiles:
#  https://github.com/Project-OSRM/osrm-backend/blob/master/docker/Dockerfile-debian
#  https://raw.githubusercontent.com/VROOM-Project/vroom-docker/refs/heads/master/Dockerfile

FROM debian:trixie-slim AS builder

#export DOCKER_DEFAULT_PLATFORM=linux/amd64
# test: getconf LONG_BIT

# Let the container know that there is no TTY
ENV DEBIAN_FRONTEND noninteractive

# see: https://github.com/Project-OSRM/osrm-backend-docker/blob/master/build.sh

# This can be a gitsha, tag, or branch - anything that works with `git checkout`
ARG OSRM_VERSION=v6.0.0

# This is passed to cmake for osrm-backend.  All other dependencies are built in
# release mode.
ARG BUILD_TYPE=Release
#ARG BUILD_TYPE=Debug

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

COPY . /src
WORKDIR /src

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

# Quick tests:
RUN /usr/local/bin/osrm-extract --help && \
    /usr/local/bin/osrm-routed --help && \
    /usr/local/bin/osrm-contract --help && \
    /usr/local/bin/osrm-partition --help && \
    /usr/local/bin/osrm-customize --help

RUN /usr/sbin/useradd osrm -m -s /bin/bash

EXPOSE 5000


# VROOM:

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

RUN echo "Cloning vroom release/branch ${VROOM_RELEASE}..." && \
    git clone --branch $VROOM_RELEASE --single-branch --recurse-submodules https://github.com/VROOM-Project/vroom.git && \
    echo "Patching VROOM to use MLD instead of CH - only MLD works with libosrm" && \
    patch -d /src/vroom -p1 < /src/vroom-MLD-patch.diff && \
    echo "Building VROOM ${VROOM_RELEASE} with $(nproc) cpus" && \
    cd /src/vroom/src && \
    make -j$(nproc) && \
    cd .. && \
    install -s bin/vroom /usr/local/bin/

ARG VROOM_EXPRESS_RELEASE=master

RUN echo "Cloning and installing vroom-express release/branch ${VROOM_EXPRESS_RELEASE}..." && \
    git clone --branch $VROOM_EXPRESS_RELEASE --single-branch https://github.com/VROOM-Project/vroom-express.git

WORKDIR /src/vroom-express

RUN apt-get update > /dev/null && \
    apt-get install -y --no-install-recommends \
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

ENTRYPOINT ["/bin/bash"]
CMD ["/conf/docker-entrypoint.sh"]
