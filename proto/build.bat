

@echo off
setlocal enabledelayedexpansion

set RootDir=%~dp0
set ProtoDir=%RootDir%\..\bin\proto\

rmdir /Q /S %ProtoDir%
md %ProtoDir%

for %%i in (*.proto) do (
	set name=%%i
	set name=!name:~0,-6!
	echo !name!
	
	protoc.exe --descriptor_set_out=%ProtoDir%\!name!.pb !name!.proto
)

pause

