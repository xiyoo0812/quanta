# lmongo
基于C++17的Lua MongoDB驱动和Bson解析库！

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)
- [lcodec](https://github.com/xiyoo0812/lcodec.git)
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--luakit <br>
  &emsp;|--lcodec <br>
  &emsp;|--lmongo

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f lmongo.mak

