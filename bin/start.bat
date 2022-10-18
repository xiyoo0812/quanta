taskkill /f /im quanta.exe

start "monitor" quanta.exe monitor.conf --index=1
start "router"  quanta.exe router.conf  --index=1
start "admin"   quanta.exe admin.conf   --index=1
start "online"  quanta.exe online.conf  --index=1
::start "mongo"   quanta.exe mongo.conf   --index=1
::start "mysql"   quanta.exe mysql.conf   --index=1
::start "redis"   quanta.exe redis.conf   --index=1