FROM ubuntu:focal

# Common setup
WORKDIR /root

# Prepare directories
RUN mkdir -p /tools/esp

# Avoiding user interaction with tzdata in a docker container
ENV DEBIAN_FRONTEND=noninteractive

# Install common deps
RUN apt-get -qq update && apt-get -qq install git cmake
RUN apt-get install zlib1g-dev libssl-dev -y

# Install minicom
RUN apt-get install minicom -y

# Install esp-idf deps
RUN apt-get -qq update && apt-get install git wget flex bison gperf python3 python3-pip python3-venv python3-setuptools python3-serial cmake ninja-build ccache libffi-dev libssl-dev dfu-util libusb-1.0-0 -y

# Install erlang OTP 21.0
RUN apt-get install libncurses5  libsctp1 libwxbase3.0-0v5 libwxgtk3.0-gtk3-0v5 libssl1.1 gnupg -y
RUN wget http://packages.erlang-solutions.com/erlang/debian/pool/esl-erlang_21.3.8.14-1~ubuntu~focal_amd64.deb &&\
    dpkg -i esl-erlang_21.3.8.14-1~ubuntu~focal_amd64.deb &&\
    wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc &&\
    apt-key add erlang_solutions.asc &&\
    apt-get install esl-erlang -y

WORKDIR /tools

#DEK network needs following commands to clone github
#note that DEKVN-CA.crt needs to be located in docker/20.04 folder
#RUN apt-get --no-install-recommends install -y ca-certificates
#ADD DEKVN-CA.crt /usr/local/share/ca-certificates/foo.crt
#RUN chmod 644 /usr/local/share/ca-certificates/foo.crt && update-ca-certificates

# RUN git clone -b 3.20.0 --recursive https://github.com/erlang/rebar3.git rebar3 &&\
#     cd rebar3 &&\
#     ./bootstrap &&\
#     ./rebar3 local install

RUN git clone -b 3.20.0 --recursive https://github.com/erlang/rebar3.git rebar3 &&\
    cd rebar3 &&\
    git checkout 3f563feaf1091a1980241adefa83a32dd2eebf7c &&\
    ./bootstrap &&\
    ./rebar3 local install

ENV PATH $PATH:/root/.cache/rebar3/bin

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

# Clone and build esp-idf v4.4-rc
RUN git clone -b release/v4.4 --recursive https://github.com/espressif/esp-idf.git esp-idf

RUN $IDF_PATH/install.sh esp32

WORKDIR /tools

# Build AtomVm
RUN git clone https://github.com/atomvm/AtomVM
WORKDIR /tools/AtomVM
RUN git checkout 3d7447965d72ce603914e21307563b8cfbb86fef

# Build esp32 platform
WORKDIR /tools/AtomVM/src/platforms/esp32
RUN . $IDF_PATH/export.sh && python3 $IDF_PATH/tools/idf.py reconfigure &&\
    python3 $IDF_PATH/tools/idf.py build

# Get back to root directory
WORKDIR /root

# Install sphinx & sphinx's dependencies
RUN python3 -m pip install sphinx &&\
    python3 -m pip install myst-parser &&\
    python3 -m pip install sphinx-rtd-theme
RUN apt-get install screen vim -y

CMD /bin/bash
