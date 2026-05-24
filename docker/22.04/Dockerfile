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
# NOTE: This Dockerfile may be out of date. Prefer using the 24.04 version instead.
#

FROM ubuntu:jammy

# Common setup
WORKDIR /root

## Install esp-idf deps
RUN apt-get -qq update &&\
 apt-get -qq install git wget flex bison gperf python3 python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 -y &&\
 apt-get -qq install pip -y

RUN python3 -m pip install pyserial

## Install minicom
RUN apt-get -qq install minicom -y &&\
apt-get -qq install screen vim -y

## Fix "No CMAKE_CXX_COMPILER could be found" issue
RUN apt-get install build-essential -y

## needed for make command to build atomvm
RUN apt-get install zlib1g-dev -y


# ESP 32
## Prepare directories
RUN mkdir -p /tools/esp

## Work in esp directory
WORKDIR /tools/esp

## Clone and build esp-idf v5.0.2
RUN git clone -b v5.0.2 --recursive https://github.com/espressif/esp-idf.git esp-idf

## Export IDF_PATH
ENV IDF_PATH /tools/esp/esp-idf
RUN $IDF_PATH/install.sh esp32


# AtomVM
WORKDIR /tools

## Build AtomVm
RUN git clone https://github.com/atomvm/AtomVM
WORKDIR /tools/AtomVM

## Build esp32 platform
WORKDIR /tools/AtomVM/src/platforms/esp32
RUN . $IDF_PATH/export.sh && python3 $IDF_PATH/tools/idf.py build


# Install erlang OTP 25.0 (we need to install many deps in this way!)
# WORKDIR /root
# RUN apt-get install erlang-mode libncurses5 libtinfo5 libwxbase3.0-0v5 libwxgtk3.0-gtk3-0v5 libsctp1
# RUN apt-get install libcairo2 libgdk-pixbuf-2.0-0 libgl1 libglib2.0-0 libgtk-3-0 libnotify4 libpango-1.0-0 libpangocairo-1.0-0 libsm6 -y
# RUN wget http://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_25.2.3-1~ubuntu~jammy_amd64.deb &&\
#     dpkg -i esl-erlang_25.2.3-1~ubuntu~jammy_amd64.deb &&\
#     wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc &&\
#     apt-key add erlang_solutions.asc &&\
#     apt-get install esl-erlang -y

# Install Erlang OTP 25 and rebar
WORKDIR /root
RUN apt-get -qq install curl
RUN apt-get -qq install libncurses5-dev libncursesw5-dev

RUN curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl &&\
    chmod a+x kerl &&\
    ./kerl build 25.3.2.3 &&\
    ./kerl install 25.3.2.3 ~/25.3.2.3 &&\
    echo ". /root/25.3.2.3/activate" >> ~/.bashrc

RUN . /root/25.3.2.3/activate &&\
git clone --branch 3.20.0 --recursive https://github.com/erlang/rebar3.git rebar3 &&\
    cd rebar3 &&\
    ./bootstrap &&\
    ./rebar3 local install

ENV PATH $PATH:/root/.cache/rebar3/bin

# Get back to root directory
WORKDIR /root

CMD /bin/bash
