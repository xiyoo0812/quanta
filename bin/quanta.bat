taskkill /f /im quanta.exe

::start "accord"   quanta.exe config/accord.conf   --index=1 --port=1
start "discover" quanta.exe config/discover.conf --index=1 --port=1
start "router1"  quanta.exe config/router.conf   --index=1 --port=1
start "router2"  quanta.exe config/router.conf   --index=2 --port=2
start "cache1"   quanta.exe config/cache.conf    --index=1 --port=1
start "mongo"    quanta.exe config/mongo.conf    --index=1 --port=1
start "redis"    quanta.exe config/redis.conf    --index=1 --port=1
start "gate1"    quanta.exe config/gateway.conf  --index=1 --port=1
start "center"   quanta.exe config/center.conf   --index=1 --port=1
start "online"   quanta.exe config/online.conf   --index=1 --port=1
start "login"    quanta.exe config/login.conf    --index=1 --port=1
start "lobby"    quanta.exe config/lobby.conf    --index=1 --port=1
