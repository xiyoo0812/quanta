#!/bin/bash

pkill -9 quanta

export LD_LIBRARY_PATH=`pwd`

ulimit -c unlimited

./quanta ./config/test.conf  --index=1 --port=1&
#./quanta ./config/test.conf  --index=2 --port=2&