@echo off

chcp 65001

set RootDir=%~dp0
set XlsmDir=%RootDir%\cfg_xls

:: 解析xlsm文件为lua
..\bin\quanta.exe .\excel2lua.conf --input=./cfg_xls --output=./config

pause

