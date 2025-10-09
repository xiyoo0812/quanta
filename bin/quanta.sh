
#!/bin/bash

pkill -9 quanta

export LD_LIBRARY_PATH=`pwd`

ulimit -c unlimited

./quanta ./config/discover.conf --index=1 --port=1&
./quanta ./config/router.conf  --index=1 --port=1&
./quanta ./config/router.conf  --index=2 --port=2&
./quanta ./config/mongo.conf   --index=1 --port=1&
./quanta ./config/redis.conf   --index=1 --port=1&
./quanta ./config/cache.conf   --index=1 --port=1&
./quanta ./config/gateway.conf --index=1 --port=1&
./quanta ./config/center.conf  --index=1 --port=1&
./quanta ./config/login.conf   --index=1 --port=1&
./quanta ./config/lobby.conf   --index=1 --port=1&
