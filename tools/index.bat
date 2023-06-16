@echo off

chcp 65001

:: 解析xlsm文件为lua

set LUA_PATH=!/../tools/mongo/?.lua;!/../script/?.lua;;

..\bin\quanta.exe --entry=index --input=../server/config/ --output=../tools/

pause

