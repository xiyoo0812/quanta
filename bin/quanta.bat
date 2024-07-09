taskkill /f /im quanta.exe

::start "accord"  quanta.exe configs/accord.conf  --index=1 --port=1
start "discover" quanta.exe configs/discover.conf --index=1 --port=1
start "router1" quanta.exe configs/router.conf  --index=1 --port=1
start "router2" quanta.exe configs/router.conf  --index=2 --port=2
start "cache1"  quanta.exe configs/cache.conf   --index=1 --port=1
start "mongo"   quanta.exe configs/mongo.conf   --index=1 --port=1
start "redis"   quanta.exe configs/redis.conf   --index=1 --port=1
start "gate1"   quanta.exe configs/gateway.conf --index=1 --port=1
start "center"  quanta.exe configs/center.conf  --index=1 --port=1
start "login"   quanta.exe configs/login.conf   --index=1 --port=1
start "lobby"   quanta.exe configs/lobby.conf   --index=1 --port=1
