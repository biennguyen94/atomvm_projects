#!/usr/bin/env bash

set -e

docker pull biennguyen94/atomvm:debian13_v1
docker run --privileged -v /dev/:/dev/ -d --name bien_atomvm -it biennguyen94/atomvm:debian13_v1 bash
docker exec bien_atomvm git -C /tools/atomvm_projects pull