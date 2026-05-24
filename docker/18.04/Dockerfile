#
# This file is part of AtomVM.
#
# Copyright 2024 Bien Nguyen <nguyennhubientdh94@gmail.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0 OR LGPL-2.1-or-later
#

FROM ubuntu:bionic

# Common setup
WORKDIR /root

# Prepare directories
RUN mkdir -p /tools/esp

# Install common deps
RUN apt-get -qq update && apt-get -qq install git cmake
RUN apt-get install zlib1g-dev libssl-dev -y

# Install minicom
RUN apt-get install minicom -y

# Install esp-idf deps
RUN apt-get -qq update && apt-get -qq install wget make libncurses-dev flex bison gperf \
    python python-pip python-setuptools python-serial python-cryptography \
    python-future python-pyparsing python-pyelftools

# Install erlang OTP 21.0
RUN apt-get -qq update && apt-get install libwxbase3.0-0v5 libwxgtk3.0-0v5 libsctp1 -y
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
    tar xf xtensa-toolchain.tar.gz

# Add xtensa toolchain to path
ENV PATH $PATH:/tools/esp/xtensa-esp32-elf/bin

# Export IDF_PATH
ENV IDF_PATH /tools/esp/esp-idf

# Clone and build esp-idf v3.2-rc
RUN git clone -b v3.2 --recursive https://github.com/espressif/esp-idf.git esp-idf && \
    python -m pip install --user -r $IDF_PATH/requirements.txt

WORKDIR /tools

# Build AtomVm
RUN git clone -b release-0.5 https://github.com/atomvm/AtomVM


# Get back to root directory
WORKDIR /root

CMD /bin/bash
