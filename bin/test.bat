taskkill /f /im quanta.exe

start "discover" quanta.exe configs/discover.conf --index=1 --port=1
start "router1" quanta.exe configs/router.conf  --index=1 --port=1
start quanta.exe ./configs/test.conf --index=1
start quanta.exe ./configs/test.conf --index=2
