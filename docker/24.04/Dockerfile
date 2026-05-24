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

FROM ubuntu:noble

# Common setup
WORKDIR /root

## Install esp-idf deps
RUN apt-get -qq update &&\
apt-get -qq install git wget flex bison gperf python3 python3-pip python3-venv cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0

## Install minicom
RUN apt-get -qq install minicom -y &&\
apt-get -qq install screen vim -y


# ESP 32
## Prepare directories
RUN mkdir -p /tools/esp

## Work in esp directory
WORKDIR /tools/esp

## Clone and build esp-idf v5.0.2
RUN git clone -b v5.5.2 --recursive https://github.com/espressif/esp-idf.git esp-idf

## Export IDF_PATH
ENV IDF_PATH /tools/esp/esp-idf
RUN $IDF_PATH/install.sh esp32


# AtomVM
WORKDIR /tools

## Clone atomvm_projects
RUN git clone https://github.com/biennguyen94/atomvm_projects.git

## Clone and Build AtomVm
RUN git clone https://github.com/atomvm/AtomVM
WORKDIR /tools/AtomVM
RUN git checkout v0.7.0-alpha.1

## Build esp32 platform
WORKDIR /tools/AtomVM/src/platforms/esp32
RUN bash -c '. $IDF_PATH/export.sh && python3 $IDF_PATH/tools/idf.py build'
ENV PATH /tools/esp/esp-idf/components/espcoredump:\
/tools/esp/esp-idf/components/partition_table:\
/tools/esp/esp-idf/components/app_update:\
/root/.espressif/tools/xtensa-esp-elf-gdb/16.3_20250913/xtensa-esp-elf-gdb/bin:\
/root/.espressif/tools/xtensa-esp-elf/esp-14.2.0_20251107/xtensa-esp-elf/bin:\
/root/.espressif/tools/esp32ulp-elf/2.38_20240113/esp32ulp-elf/bin:\
/root/.espressif/tools/openocd-esp32/v0.12.0-esp32-20250707/openocd-esp32/bin:\
/root/.espressif/python_env/idf5.5_py3.12_env/bin:\
/tools/esp/esp-idf/tools:$PATH

# https://doc.atomvm.org/latest/release-notes.html
# https://prying.io/technical/2018/09/18/using-kerl-and-kiex-for-version-management.html
# https://github.com/kerl/kerl
# https://github.com/taylor/kiex

# Install Erlang OTP 29 and rebar
WORKDIR /root
RUN apt-get -qq update && apt-get -qq install curl
RUN apt-get -qq install libncurses5-dev libncursesw5-dev

RUN apt-get -qq install build-essential autoconf m4 libwxgtk3.2-dev libwxgtk-webview3.2-dev libgl1-mesa-dev libglu1-mesa-dev libpng-dev libssh-dev unixodbc-dev xsltproc fop libxml2-utils libncurses-dev openjdk-11-jdk

RUN curl -O https://raw.githubusercontent.com/kerl/kerl/master/kerl &&\
    chmod a+x kerl &&\
    ./kerl update releases &&\
    ./kerl build 29.0 &&\
    ./kerl install 29.0 ~/29.0 &&\
    echo ". /root/29.0/activate" >> ~/.bashrc

RUN . /root/29.0/activate &&\
git clone --branch 3.27.0 --recursive https://github.com/erlang/rebar3.git rebar3 &&\
    cd rebar3 &&\
    ./bootstrap &&\
    ./rebar3 local install

ENV PATH $PATH:/root/29.0/bin:/root/29.0/.cache/rebar3/bin

# Install Elixir 1.19.5
SHELL ["/bin/bash", "-c"]
RUN \curl -sSL https://raw.githubusercontent.com/taylor/kiex/master/install | bash -s &&\
    echo 'test -s "$HOME/.kiex/scripts/kiex" && source "$HOME/.kiex/scripts/kiex"' >> ~/.bashrc &&\
    source "$HOME/.kiex/scripts/kiex" &&\
    kiex install 1.19.5 &&\
    ELIXIR_VERSION=$(ls /root/.kiex/elixirs/ | grep '1.19.5' | head -1 | sed 's/elixir-//' | sed 's/\.env//') &&\
    kiex use "$ELIXIR_VERSION" &&\
    kiex default "$ELIXIR_VERSION"

# Get back to root directory
WORKDIR /root

CMD /bin/bash
