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

# 执行测试代码
测试代码位于server/test，入口文件为server/test.lua
```
cd bin
./quanta ./test.conf
```

# 基础服务
- router: quanta框架采用星形结构，router提供路由服务。
- test: 测试组件，提供基本给你测试的服务
- dbsvr: 提供基础的数据库访问服务。
- proxy: 提供基础的http访问服务。
- cachesvr: 提供基础的数据缓存服务。
- monitor: 提供基于httpserver服务，以及服务启停、监控的服务。

# 依赖
- bson(云风版)
- lfs
- lnet
- lpeg
- lua(5.4)
- lcjson
- loalog
- luaxlsx
- mongo(云风版)
- pbc
- webclient
- luna
- luabus
- luabt
- lhttp
- lcrypt

# 支持功能
- excel(xlsx/xlsm)配置导出
- mongo数据库支持
- mysql数据库支持
- protobuf协议支持
- json协议支持
- http服务器支持
- http客户端访问
- tcp服务器/客户端支持
- rpc调用机制支持
- 协议加密和压缩功能支持
- 行为树ai功能支持
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

