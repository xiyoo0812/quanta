#!/bin/bash

pkill -9 quanta

export LD_LIBRARY_PATH=`pwd`

ulimit -c unlimited

./quanta ./configs/test.conf  --index=1 --port=1&
#./quanta ./configs/test.conf  --index=2 --port=2&