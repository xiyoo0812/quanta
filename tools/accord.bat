@echo off

chcp 65001

:: 解析xlsm文件为lua

set LUA_PATH=!/../tools/accord/?.lua;!/../script/?.lua;;

..\bin\quanta.exe --entry=accord --proto=../bin/proto/ --input=./accord/ --output=../server/robot/accord/

pause

