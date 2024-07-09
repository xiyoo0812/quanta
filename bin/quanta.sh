
#!/bin/bash

pkill -9 quanta

export LD_LIBRARY_PATH=`pwd`

ulimit -c unlimited

./quanta ./configs/discover.conf --index=1 --port=1&
./quanta ./configs/router.conf  --index=1 --port=1&
./quanta ./configs/router.conf  --index=2 --port=2&
./quanta ./configs/mongo.conf   --index=1 --port=1&
./quanta ./configs/redis.conf   --index=1 --port=1&
./quanta ./configs/cache.conf   --index=1 --port=1&
./quanta ./configs/gateway.conf --index=1 --port=1&
./quanta ./configs/center.conf  --index=1 --port=1&
./quanta ./configs/login.conf   --index=1 --port=1&
./quanta ./configs/lobby.conf   --index=1 --port=1&
