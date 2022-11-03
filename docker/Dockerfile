FROM ubuntu:bionic

# Common setup
WORKDIR /root

# Prepare directories
RUN mkdir -p /tools/esp

# Install common deps
RUN apt-get -qq update && apt-get -qq install git cmake
RUN apt-get install zlib1g-dev libssl-dev -y

# Install esp-idf deps
RUN apt-get -qq install wget make libncurses-dev flex bison gperf \
    python python-pip python-setuptools python-serial python-cryptography \
    python-future python-pyparsing python-pyelftools

# Install erlang OTP 21.0
RUN apt-get install libwxbase3.0-0v5 libwxgtk3.0-0v5 libsctp1 -y
RUN wget https://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_21.0-1~ubuntu~bionic_amd64.deb &&\
    dpkg -i esl-erlang_21.0-1~ubuntu~bionic_amd64.deb &&\
    wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc &&\
    apt-key add erlang_solutions.asc &&\
    apt-get install esl-erlang -y

WORKDIR /tools

RUN git clone --branch 3.20.0 --recursive https://github.com/erlang/rebar3.git rebar3 &&\
    cd rebar3 &&\
    ./bootstrap &&\
    ./rebar3 local install

ENV PATH $PATH:/root/.cache/rebar3/bin

# Add gcc-arm-embedded ppa and install gcc-arm-embedded
RUN echo "deb http://ppa.launchpad.net/team-gcc-arm-embedded/ppa/ubuntu bionic main" >> /etc/apt/sources.list && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys D1FAA6ECF64D33B0 && \
    apt-get -qq update && apt-get -qq install gcc-arm-embedded

# ESP 32

# Work in esp directory
WORKDIR /tools/esp

# Get xtensa toolchain
RUN wget https://dl.espressif.com/dl/xtensa-esp32-elf-linux64-1.22.0-80-g6c4433a-5.2.0.tar.gz -O xtensa-toolchain.tar.gz && \
    tar xf xtensa-toolchain.tar.gz && \
    rm xtensa-toolchain.tar.gz

# Add xtensa toolchain to path
ENV PATH $PATH:/tools/esp/xtensa-esp32-elf/bin

# Export IDF_PATH
ENV IDF_PATH /tools/esp/esp-idf

# Clone and build esp-idf v3.2-rc
RUN git clone -b v3.2 --recursive https://github.com/espressif/esp-idf.git esp-idf && \
    python -m pip install --user -r $IDF_PATH/requirements.txt

WORKDIR /tools

# Build AtomVm
RUN git clone https://github.com/atomvm/AtomVM


# Get back to root directory
WORKDIR /root

CMD /bin/bash
