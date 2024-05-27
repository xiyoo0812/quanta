#工程名字
PROJECT_NAME = lyaml

#目标名字
TARGET_NAME = lyaml

#系统环境
UNAME_S = $(shell uname -s)

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#CFLAG
MYCFLAGS =

#需要定义的FLAG
MYCFLAGS += -Wno-sign-compare
MYCFLAGS += -Wno-unused-variable
MYCFLAGS += -Wno-unused-parameter
MYCFLAGS += -Wno-unused-but-set-variable
MYCFLAGS += -Wno-unused-but-set-parameter

#c标准库版本
#gnu99/gnu11/gnu17
STDC = -std=gnu99

#c++标准库版本
#c++11/c++14/c++17/c++20
STDCPP = -std=c++17

#需要的include目录
MYCFLAGS += -I./src
MYCFLAGS += -I../lua/lua
MYCFLAGS += -I../luakit/include

#需要定义的选项
MYCFLAGS += -DYAML_DECLARE_EXPORT

#LDFLAGS
LDFLAGS =


#需要连接的库文件
LIBS =
ifneq ($(UNAME_S), Darwin)
#是否启用mimalloc库
LIBS += -lmimalloc
MYCFLAGS += -I$(SOLUTION_DIR)extend/mimalloc/mimalloc/include -include ../../mimalloc-ex.h
endif
#自定义库
LIBS += -llua
#系统库
LIBS += -lm -ldl -lstdc++ -lpthread

#定义基础的编译选项
ifndef CC
CC = gcc
endif
ifndef CX
CX = c++
endif
CFLAGS = -g -O2 -Wall -Wno-deprecated $(STDC) $(MYCFLAGS)
CXXFLAGS = -g -O2 -Wall -Wno-deprecated $(STDCPP) $(MYCFLAGS)

#项目目录
ifndef SOLUTION_DIR
SOLUTION_DIR=./
endif

#临时文件目录
INT_DIR = $(SOLUTION_DIR)temp/$(PROJECT_NAME)

#目标文件前缀，定义则.so和.a加lib前缀，否则不加
PROJECT_PREFIX =

#目标定义
MYCFLAGS += -fPIC
TARGET_DIR = $(SOLUTION_DIR)bin
TARGET_DYNAMIC =  $(TARGET_DIR)/$(PROJECT_PREFIX)$(TARGET_NAME).so
#soname
ifeq ($(UNAME_S), Linux)
LDFLAGS += -Wl,-soname,$(PROJECT_PREFIX)$(TARGET_NAME).so
endif
#install_name
ifeq ($(UNAME_S), Darwin)
LDFLAGS += -Wl,-install_name,$(PROJECT_PREFIX)$(TARGET_NAME).so
endif

#link添加.so目录
LDFLAGS += -L$(SOLUTION_DIR)bin
LDFLAGS += -L$(SOLUTION_DIR)library

#自动生成目标
SOURCES =
SOURCES += src/api.c
SOURCES += src/dumper.c
SOURCES += src/emitter.c
SOURCES += src/loader.c
SOURCES += src/lyaml.cpp
SOURCES += src/parser.c
SOURCES += src/reader.c
SOURCES += src/scanner.c
SOURCES += src/writer.c

CSOURCES = $(patsubst %.c, $(INT_DIR)/%.o, $(SOURCES))
MSOURCES = $(patsubst %.m, $(INT_DIR)/%.o, $(CSOURCES))
CCSOURCES = $(patsubst %.cc, $(INT_DIR)/%.o, $(MSOURCES))
OBJS = $(patsubst %.cpp, $(INT_DIR)/%.o, $(CCSOURCES))

# 编译所有源文件
$(INT_DIR)/%.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@
$(INT_DIR)/%.o : %.m
	$(CC) $(CFLAGS) -c $< -o $@
$(INT_DIR)/%.o : %.cc
	$(CX) $(CXXFLAGS) -c $< -o $@
$(INT_DIR)/%.o : %.cpp
	$(CX) $(CXXFLAGS) -c $< -o $@

$(TARGET_DYNAMIC) : $(OBJS)
	$(CC) -o $@ -shared $(OBJS) $(LDFLAGS) $(LIBS)

#target伪目标
target : $(TARGET_DYNAMIC)

#clean伪目标
clean :
	rm -rf $(INT_DIR)

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(TARGET_DIR)
	mkdir -p $(INT_DIR)/src

#后编译
post_build:
