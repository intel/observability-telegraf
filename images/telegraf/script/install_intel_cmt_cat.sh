#!/bin/bash

git clone -b v4.4.1 https://github.com/intel/intel-cmt-cat.git && cd intel-cmt-cat || exit

make
sudo NOLDCONFIG=y make install
cd .. && rm -r intel-cmt-cat
