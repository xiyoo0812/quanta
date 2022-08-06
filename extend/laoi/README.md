# laoi
一个提供给C/Lua使用的MMO视野管理(AOI)组件。

# 依赖
- [lua](https://github.com/xiyoo0812/lua.git)5.2以上
- [luakit](https://github.com/xiyoo0812/luakit.git)
- 项目路径如下<br>
  |--proj <br>
  &emsp;|--lua <br>
  &emsp;|--luakit <br>
  &emsp;|--laoi

# 编译
- msvc: 准备好lua依赖库并放到指定位置，将proj文件加到sln后编译。
- linux: 准备好lua依赖库并放到指定位置，执行make -f laoi.mak

# 注意事项
- mimalloc: 参考[quanta](https://github.com/xiyoo0812/quanta.git)使用，不用则在工程文件中注释

# 用法
```lua
```