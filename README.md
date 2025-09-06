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
- 目前主分支升级到c++20，建议使用c++20支持的编译器
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
在bin/config目录下，仿造quanta.conf生成配置实例，然后在bin目录执行setup.bat/setup.sh，会自动生成项目配置
```shell
#linux
#需要加参数配置文件名
setup.sh quanta
#windows
setup.bat
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
- discover: 提供服务发现功能，以及基于http提供启停、监控的服务。

# 数据库支持
- mongo
- redis
- mysql
- pgsql
- sqlite
- clickhouse

# KV存储支持
- redis
- lmdb
- smdb
- etcd
- unqite

# 支持功能
- SSL支持
- GRPC C支持
- TCP/UDP C/S支持
- websocket C/S支持
- HTTP/HTTP2 C/S支持
- protobuf协议支持
- json/xml/yaml/toml配置支持
- excel(xlsx/xlsm/csv)配置导出
- 常用压缩算法(lz4,minizip,zstd)支持
- 常用加密算法(BASE64,MD5,RSA,SHA系列,hmac系列)支持
- rpc调用机制支持
- 协议加密和压缩功能支持
- 文件系统支持
- 异步日志功能支持
- lua面向对象机制支持
- 性能/流量统计支持
- 游戏数据缓存机制支持
- 脚本文件加密机制支持
- 游戏逻辑/配置热更新机制支持
- 协程调用框架
- 游戏GM功能框架
- 服务发现功能框架
- 基于行为树的机器人测试框架
- 星型分布式服务器框架

# 辅助工具
- GMWeb工具
- loki日志系统
- 协议测试Web工具
- zipkin调用链系统
- dingding/wechat/lark等webhook通知
