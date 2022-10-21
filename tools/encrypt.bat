@echo off

chcp 65001

set LUA_PATH=!/../tools/encrypt/?.lua;!/../script/?.lua;;

:: 编码lua文件
..\bin\quanta.exe --entry=encrypt --input=../script --output=./export

pause

