taskkill /f /im quanta.exe

start "router"  quanta.exe router.conf  --index=1
start "monitor" quanta.exe monitor.conf --index=1
start "admin"   quanta.exe admin.conf   --index=1
start "mongo"   quanta.exe mongo.conf   --index=1
start "mysql"   quanta.exe mysql.conf   --index=1
start "redis"   quanta.exe redis.conf   --index=1
start "influx"  quanta.exe influx.conf  --index=1
start "proxy"   quanta.exe proxy.conf   --index=1
start "online"  quanta.exe online.conf  --index=1