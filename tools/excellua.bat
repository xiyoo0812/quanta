@echo off

chcp 65001

:: 解析xlsm文件为lua
..\bin\quanta.exe .\excel2lua.conf --input=./cfg_xls --output=./config

pause

