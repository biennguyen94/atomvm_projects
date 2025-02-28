# Copyright 2022 Bien Nguyen <nguyennhubientdh94@gmail.com>

FROM ubuntu:focal

# Common setup
WORKDIR /root

ENV DEBIAN_FRONTEND=noninteractive

# Install common deps
RUN apt-get -qq update && apt-get -qq install git cmake

RUN apt-get -qq install python3 python3-pip python3-venv python3-setuptools python3-serial

# Install sphinx & sphinx's dependencies
RUN python3 -m pip install sphinx &&\
    python3 -m pip install myst-parser &&\
    python3 -m pip install sphinx-rtd-theme

RUN apt-get install screen vim -y

RUN git clone https://github.com/biennguyen94/GoodLuck.git &&\
    mkdir /root/GoodLuck/build &&\
    cd /root/GoodLuck/build &&\
    cmake .. &&\
    make sphinx-html


CMD /bin/bash

