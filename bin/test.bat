taskkill /f /im quanta.exe

#start "discover" quanta.exe config/discover.conf --index=1 --port=1
#start "router1" quanta.exe config/router.conf  --index=1 --port=1
start quanta.exe ./config/test.conf --index=1
#start quanta.exe ./config/test.conf --index=2
