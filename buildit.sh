#!/bin/bash
basepath=$(cd `dirname $0`; pwd)
echo "current dir $basepath"
test -e vnpy_rpcservice || git clone git@github.com:ChuangZhang/vnpy_rpcservice.git
test -e vnpy || git clone git@github.com:ChuangZhang/vnpy.git
sudo docker build -t zchuang:vnpy --rm --force-rm  --build-arg USERNAME=zchuang .
