# quanta

# 概述
一个基于lua的分布式游戏服务器引擎框架！

# 优势
- 轻量级
- 简单、易上手
- 稳定性强
- 扩展性强
- 热更新

# 编译
- msvc : 打开项目目录下的sln工程文件，编译即可。
- linux：在项目根目录，执行make all。
- 编译lua需要readline，请提前安装。
- http模块依赖curl，请提前安装。

# 工程
- 本项目使用[lmake](https://github.com/xiyoo0812/lmake.git)管理
- 根目录配置lmake
```lua
--lmake
--工程名
SOLUTION = "quanta"
--lmake目录
LMAKE_DIR = "extend/lmake"
--mimalloc
MIMALLOC = false
```
- 子项目配置*.lmake
- 执行以下指令自动生成项目文件(makefile/vcxproj)
```shell
# lmake_dir: lmake项目路径
# solution_dir: 工程根目录
./lua lmake_dir/lmake.lua solution_dir
```

# 体验引擎
- 配置
在bin/config目录下，仿造quanta.conf生成配置实例，然后在bin目录执行configure.bat/configure.sh，会自动生成项目配置
```shell
#linux
#需要加参数配置文件名
configure.sh quanta
#windows
configure.bat
#然后输入配置文件名
#>>quanta
```
- 执行
可以bin下的quanta.bat/quanta.sh, test.bat/test.sh体验
```shell
#linux
quanta.sh
#windows
quanta.bat
```

# 基础服务
- router: quanta框架采用星形结构，router提供路由服务。
- test: 测试组件，提供基本给你测试的服务
- dbsvr: 提供基础的数据库访问服务。
- proxy: 提供基础的http访问服务。
- cachesvr: 提供基础的数据缓存服务。
- monitor: 提供基于httpserver服务，以及服务启停、监控的服务。

# 依赖
- lua
- lbson
- lcurl
- ljson
- luabus
- lcrypt
- lstdfs
- luakit
- lualog
- lcodec
- luaxlsx
- lua-protobuf

# 数据库支持
- mongo
- mysql
- redis
- clickhouse

# 支持功能
- protobuf协议支持
- json协议支持
- http服务器支持
- http客户端访问
- websocket支持
- excel(xlsx/xlsm)配置导出
- tcp服务器/客户端支持
- rpc调用机制支持
- 协议加密和压缩功能支持
- ai功能支持
- 文件系统支持
- 异步日志功能支持
- lua面向对象机制支持
- 性能/流量统计支持
- 游戏数据缓存机制支持
- 脚本文件加密机制支持
- 游戏逻辑/配置热更新机制支持
- 协程调用框架
- 游戏GM功能框架
- 基于行为树的机器人测试框架
- 星型分布式服务器框架

# 辅助工具
- GMWeb工具
- 协议测试Web工具
- redis服务发现系统
- zipkin/jager调用链系统
- dingding/wechat/lark等webhook通知
