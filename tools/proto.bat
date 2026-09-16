@echo off

chcp 65001

set LUA_PATH=!/../tools/robot/?.lua;;

..\bin\quanta.exe --entry=proto --input=../bin/proto/ncmd_cs.pb --output=../tools/robot/proto/

pause

