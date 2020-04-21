#工程名字
PROJECT_NAME = quanta
#工程类型，可以是库(lib)或可执行程序(exe)
PROJECT_TYPE = exe

#是否静态库，定义后生成.a文件，否则生成.so文件
#_STATIC=

#c++11
STDC_EX= -std=c++11

# share.mak包含了一些编译选项，在这里可以添加新的选项和include目录
MYCFLAGS = -fpermissive -I../../extend/lua/src -I../luna/src -Wno-unused-parameter -Wno-unused-variable -Wno-unused-but-set-parameter

#share.mak包含了一些链接选项，在这里可以添加新的选项和lib目录
#MYLDFLAGS =

#share.mak包含了一些公用的库,这里加上其他所需的库
MYLIBS = -llua -lluna -lpthread

#源文件路径
#SRC_DIR=

#目标文件，可以在这里定义，如果没有定义，share.mak会自动生成
#MYOBJS=

#需要排除的源文件
#EXCLUDE_FILE=

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#通用规则
include ../../share/share.mak

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(TARGET_DIR)

#后编译
post_build:

