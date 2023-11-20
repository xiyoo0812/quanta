taskkill /f /im quanta.exe

::start "accord"  quanta.exe quanta\accord.conf  --index=1 --port=1
start "monitor" quanta.exe quanta\monitor.conf --index=1 --port=1
start "router1" quanta.exe quanta\router.conf  --index=1 --port=1
start "cache1"  quanta.exe quanta\cache.conf   --index=1 --port=1
start "mongo"   quanta.exe quanta\mongo.conf   --index=1 --port=1
start "redis"   quanta.exe quanta\redis.conf   --index=1 --port=1
start "gate1"   quanta.exe quanta\gateway.conf --index=1 --port=1
start "center"  quanta.exe quanta\center.conf  --index=1 --port=1
start "login"   quanta.exe quanta\login.conf   --index=1 --port=1
