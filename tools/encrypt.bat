@echo off

chcp 65001

cd ../bin

set LUA_PATH=!/../tools/encrypt/?.lua;;

:: 编码lua文件
quanta.exe --entry=encrypt --input=../script --output=../tools/export

pause

