#工程名字
PROJECT_NAME = lua

#目标名字
TARGET_NAME = lua

#系统环境
UNAME_S = $(shell uname -s)

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#CFLAG
MYCFLAGS =

#需要定义的FLAG

#c标准库版本
#gnu99/gnu11/gnu17
STDC = -std=gnu99

#c++标准库版本
#c++11/c++14/c++17/c++20
STDCPP = -std=c++14

#需要的include目录
MYCFLAGS += -I./lua

#需要定义的选项
MYCFLAGS += -DMAKE_LUA

#LDFLAGS
LDFLAGS =


#源文件路径
SRC_DIR = lua

#需要排除的源文件,目录基于$(SRC_DIR)
EXCLUDE =

#需要连接的库文件
LIBS =
#是否启用mimalloc库
LIBS += -lmimalloc -lpthread
MYCFLAGS += -I../../mimalloc/mimalloc/include -include ../../mimalloc-ex.h
#系统库
LIBS += -lm -ldl -lstdc++
#自定义库

#定义基础的编译选项
CC = gcc
CX = c++
CFLAGS = -g -O2 -Wall -Wno-deprecated -Wextra -Wno-unknown-pragmas $(STDC) $(MYCFLAGS)
CXXFLAGS = -g -O2 -Wall -Wno-deprecated -Wextra -Wno-unknown-pragmas $(STDCPP) $(MYCFLAGS)

#项目目录
ifndef SOLUTION_DIR
SOLUTION_DIR=./
endif

#临时文件目录
INT_DIR = $(SOLUTION_DIR)temp/$(PROJECT_NAME)


#目标定义
TARGET_DIR = $(SOLUTION_DIR)bin
TARGET_EXECUTE =  $(TARGET_DIR)/$(TARGET_NAME)

#link添加.so目录
LDFLAGS += -L$(SOLUTION_DIR)bin
LDFLAGS += -L$(SOLUTION_DIR)library

#自动生成目标
OBJS =
COBJS = $(patsubst %.c, $(INT_DIR)/%.o, onelua.c)
MOBJS = $(patsubst %.m, $(INT_DIR)/%.o, $(COBJS))
CCOBJS = $(patsubst %.cc, $(INT_DIR)/%.o, $(MOBJS))
OBJS = $(patsubst %.cpp, $(INT_DIR)/%.o, $(CCOBJS))

# 编译所有源文件
$(INT_DIR)/%.o : $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@
$(INT_DIR)/%.o : $(SRC_DIR)/%.m
	$(CC) $(CFLAGS) -c $< -o $@
$(INT_DIR)/%.o : $(SRC_DIR)/%.cc
	$(CX) $(CXXFLAGS) -c $< -o $@
$(INT_DIR)/%.o : $(SRC_DIR)/%.cpp
	$(CX) $(CXXFLAGS) -c $< -o $@

$(TARGET_EXECUTE) : $(OBJS)
	$(CC) -o $@  $(OBJS) $(LDFLAGS) $(LIBS)

#target伪目标
target : $(TARGET_EXECUTE)

#clean伪目标
clean :
	rm -rf $(INT_DIR)

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(TARGET_DIR)

#后编译
post_build:
