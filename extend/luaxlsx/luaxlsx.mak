#工程名字
PROJECT_NAME = luaxlsx
#工程类型，可以是库(lib)或可执行程序(exe)
PROJECT_TYPE = lib

#目标文件前缀，不定义则.so和.a加lib前缀，否则不加
PROJECT_NO_PREFIX=1

#是否静态库，定义后生成.a文件，否则生成.so文件
#_STATIC=

#c++11
STDC_EX= -std=c++11

# share.mak包含了一些编译选项，在这里可以添加新的选项和include目录
MYCFLAGS = -I../lua/src -I./src/zlib -I./src/tinyxml2 -I./src/minizip -Wno-sign-compare

#share.mak包含了一些链接选项，在这里可以添加新的选项和lib目录
MYLDFLAGS = 

#share.mak包含了一些公用的库,这里加上其他所需的库
MYLIBS =

#源文件路径
SRC_DIR=./src

#需要排除的源文件
EXCLUDE_FILE=$(SRC_DIR)/minizip/minizip.c $(SRC_DIR)/minizip/miniunz.c

#目标文件，可以在这里定义，如果没有定义，share.mak会自动生成
#MYOBJS=
MYOBJS = $(patsubst $(SRC_DIR)/%.cpp, $(INT_DIR)/%.o, $(wildcard $(SRC_DIR)/*.cpp))
MYOBJS += $(patsubst $(SRC_DIR)/zlib/%.c, $(INT_DIR)/zlib/%.o, $(wildcard $(SRC_DIR)/zlib/*.c))
MYOBJS += $(patsubst $(SRC_DIR)/tinyxml2/%.cpp, $(INT_DIR)/tinyxml2/%.o, $(wildcard $(SRC_DIR)/tinyxml2/*.cpp))
MYOBJS += $(patsubst $(SRC_DIR)/minizip/%.c, $(INT_DIR)/minizip/%.o, $(filter-out $(EXCLUDE_FILE), $(wildcard $(SRC_DIR)/minizip/*.cpp)))

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#通用规则
include ../../share/share.mak

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(INT_DIR)/zlib
	mkdir -p $(INT_DIR)/minizip
	mkdir -p $(INT_DIR)/tinyxml2
	mkdir -p $(TARGET_DIR)

#指定zlib编译
$(INT_DIR)/zlib/%.o : $(SRC_DIR)/zlib/%.c
	$(CC) $(CXXFLAGS) -c $< -o $@

#指定minizip编译
$(INT_DIR)/minizip/%.o : $(SRC_DIR)/minizip/%.c
	$(CC) $(CXXFLAGS) -c $< -o $@

#指定tinyxml2编译
$(INT_DIR)/tinyxml2/%.o : $(SRC_DIR)/tinyxml2/%.cpp
	$(CX) $(CXXFLAGS) -c $< -o $@

#后编译
post_build:
