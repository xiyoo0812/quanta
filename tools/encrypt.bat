@echo off

chcp 65001

:: 编码lua文件
..\bin\quanta.exe .\encrypt.conf --input=../script --output=./export

pause

