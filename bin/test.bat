@echo off
rem ==================================================================
rem test.bat - 测试启动脚本
rem   询问是否集群测试, 无输入默认非集群;
rem   非集群: test.conf 中 QUANTA_DISCOVER/QUANTA_ROUTER 置 0, 只起 test --index=1
rem   集群  : test.conf 中 QUANTA_DISCOVER/QUANTA_ROUTER 置 1, 起 discover/router/test1/test2
rem ==================================================================
setlocal enabledelayedexpansion

rem 切换到本脚本所在目录(bin), 保证相对路径 config\xxx.conf 正确
cd /d "%~dp0"

set "CONF=config\test.conf"

rem ---------- 1. 询问是否集群测试 ----------
set "CLUSTER="
set /p CLUSTER=cluster test? (y/N):

rem 无输入或非 y/Y 一律按非集群处理
if /i "%CLUSTER%"=="y" (
    set "MODE=1"
) else (
    set "MODE=0"
)

rem ---------- 2. 按模式修改 test.conf 的开关 ----------
powershell -NoProfile -Command ^
    "$p='%CONF%'; $t=Get-Content -Raw -Encoding UTF8 $p; $t=$t -replace 'set_env\(\"QUANTA_DISCOVER\", \"[01]\"\)','set_env(\"QUANTA_DISCOVER\", \"%MODE%\")'; $t=$t -replace 'set_env\(\"QUANTA_ROUTER\", \"[01]\"\)','set_env(\"QUANTA_ROUTER\", \"%MODE%\")'; [IO.File]::WriteAllText((Resolve-Path $p), $t, [Text.UTF8Encoding]::new($false))"

if "%MODE%"=="1" (
    echo [test] cluster mode: DISCOVER=1 ROUTER=1
) else (
    echo [test] single mode: DISCOVER=0 ROUTER=0
)

rem ---------- 3. 清理残留进程 ----------
taskkill /f /im quanta.exe >nul 2>&1
rem 给系统一点时间释放端口
ping -n 2 127.0.0.1 >nul

rem ---------- 4. 按模式启动进程 ----------
if "%MODE%"=="1" (
    echo [test] start discover
    start "discover" quanta.exe config/discover.conf --index=1
    echo [test] start router
    start "router" quanta.exe config/router.conf --index=1
    rem 等 discover/router 就绪再起 test, 避免 test 找不到路由
    ping -n 3 127.0.0.1 >nul
    echo [test] start test1
    start "test1" quanta.exe config/test.conf --index=1
    echo [test] start test2
    start "test2" quanta.exe config/test.conf --index=2
) else (
    echo [test] start test1 only
    start "test1" quanta.exe config/test.conf --index=1
)

echo [test] done.
endlocal
