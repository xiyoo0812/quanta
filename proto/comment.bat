

@echo off
setlocal enabledelayedexpansion

set RootDir=%~dp0
set ProtoDir=%RootDir%\..\bin\proto\

if not exist %ProtoDir% md %ProtoDir%

set Files=
for %%i in (*.proto) do (
	echo "build %%i"
	call set "Files=%%i %%Files%%"
)
protoc.exe --include_source_info --descriptor_set_out=%ProtoDir%\comment.pb %Files%

pause

