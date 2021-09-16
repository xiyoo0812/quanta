@echo off

chcp 65001

set RootDir=%~dp0

:: 解析xlsm文件为lua
..\bin\quanta.exe ..\tools\excel2lua.conf --input=./ --output=../server/config

pause

