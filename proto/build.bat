

@echo off
setlocal enabledelayedexpansion

set RootDir=%~dp0
set ProtoDir=%RootDir%\..\bin\proto\

rmdir /Q /S %ProtoDir%
md %ProtoDir%

set Files=
for %%i in (*.proto) do (
	call set "Files=%%i %%Files%%"
)
protoc.exe --descriptor_set_out=%ProtoDir%\ncmd_cs.pb %Files%
protoc.exe --plugin=protoc-gen-json=./pbjson.exe --json_out=%ProtoDir%\ %Files%

pause

