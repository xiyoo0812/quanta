#工程名字
PROJECT_NAME = encrypt
#工程类型，可以是库(lib)或可执行程序(exe)
PROJECT_TYPE = lib

#是否静态库，定义后生成.a文件，否则生成.so文件
#_STATIC=

#目标文件前缀，不定义则.so和.a加lib前缀，否则不加
PROJECT_NO_PREFIX=1

#c++11
STDC_EX= -std=c++11

# share.mak包含了一些编译选项，在这里可以添加新的选项和include目录
MYCFLAGS = -I../lua/src -I./src/quickzip -I./src/md5

#share.mak包含了一些链接选项，在这里可以添加新的选项和lib目录
MYLDFLAGS = 

#share.mak包含了一些公用的库,这里加上其他所需的库
MYLIBS =

#源文件路径
SRC_DIR= ./src

#需要排除的源文件
#EXCLUDE_FILE=

#目标文件，可以在这里定义，如果没有定义，share.mak会自动生成
#MYOBJS=
MYOBJS = $(patsubst $(SRC_DIR)/%.cpp, $(INT_DIR)/%.o, $(wildcard $(SRC_DIR)/*.cpp))
MYOBJS += $(patsubst $(SRC_DIR)/quickzip/%.cpp, $(INT_DIR)/quickzip/%.o, $(wildcard $(SRC_DIR)/quickzip/*.cpp))
MYOBJS += $(patsubst $(SRC_DIR)/md5/%.cpp, $(INT_DIR)/md5/%.o, $(wildcard $(SRC_DIR)/md5/*.cpp))

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#通用规则
include ../../share/share.mak

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(INT_DIR)/quickzip
	mkdir -p $(INT_DIR)/md5
	mkdir -p $(TARGET_DIR)

#指定quickzip编译
$(INT_DIR)/quickzip/%.o : $(SRC_DIR)/quickzip/%.cpp
	$(CX) $(CXXFLAGS) -c $< -o $@

$(INT_DIR)/md5/%.o : $(SRC_DIR)/md5/%.cpp
	$(CX) $(CXXFLAGS) -c $< -o $@

#后编译
post_build:
