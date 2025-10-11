#工程名字
PROJECT_NAME = {{%= PROJECT_NAME %}}

#目标名字
TARGET_NAME = {{%= TARGET_NAME %}}

#系统环境
UNAME_S = $(shell uname -s)

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#CFLAG
MYCFLAGS =

#需要定义的FLAG
{{% for _, flag in ipairs(BASE_FLAGS) do %}}
MYCFLAGS += -{{%= flag %}}
{{% end %}}
{{% for _, flag in ipairs(FLAGS) do %}}
MYCFLAGS += -{{%= flag %}}
{{% end %}}
{{% if #LINUX_FLAGS > 0 then %}}
ifeq ($(UNAME_S), Linux)
{{% for _, flag in ipairs(LINUX_FLAGS) do %}}
MYCFLAGS += -{{%= flag %}}
{{% end %}}
endif
{{% end %}}
{{% if #DARWIN_FLAGS > 0 then %}}
ifeq ($(UNAME_S), Darwin)
{{% for _, flag in ipairs(DARWIN_FLAGS) do %}}
MYCFLAGS += -{{%= flag %}}
{{% end %}}
endif
{{% end %}}

{{% if STDC then %}}
#c标准库版本
#gnu99/gnu11/gnu17
STDC = -std={{%= STDC %}}
{{% end %}}

{{% if STDCPP then %}}
#c++标准库版本
#c++11/c++14/c++17/c++20/c++23
STDCPP = -std={{%= STDCPP %}}
{{% end %}}

#需要的include目录
{{% for _, include in ipairs(INCLUDES) do %}}
MYCFLAGS += -I{{%= include %}}
{{% end %}}
{{% if #LINUX_INCLUDES > 0 then %}}
ifeq ($(UNAME_S), Linux)
{{% for _, include in ipairs(LINUX_INCLUDES) do %}}
MYCFLAGS += -I{{%= include %}}
{{% end %}}
endif
{{% end %}}
{{% if #DARWIN_INCLUDES > 0 then %}}
ifeq ($(UNAME_S), Darwin)
{{% for _, include in ipairs(DARWIN_INCLUDES) do %}}
MYCFLAGS += -I{{%= include %}}
{{% end %}}
endif
{{% end %}}

#需要定义的选项
{{% if #DEFINES > 0 then %}}
{{% for _, define in ipairs(DEFINES) do %}}
MYCFLAGS += -D{{%= define %}}
{{% end %}}
{{% end %}}
{{% if #LINUX_DEFINES > 0 then %}}
ifeq ($(UNAME_S), Linux)
{{% for _, define in ipairs(LINUX_DEFINES) do %}}
MYCFLAGS += -D{{%= define %}}
{{% end %}}
endif
{{% end %}}
{{% if #DARWIN_DEFINES > 0 then %}}
ifeq ($(UNAME_S), Darwin)
{{% for _, define in ipairs(DARWIN_DEFINES) do %}}
MYCFLAGS += -D{{%= define %}}
{{% end %}}
endif
{{% end %}}

#LDFLAGS
LDFLAGS =
{{% for _, flag in ipairs(LDFLAGS) do %}}
LDFLAGS += {{%= flag %}}
{{% end %}}
{{% if #LINUX_LDFLAGS > 0 then %}}
ifeq ($(UNAME_S), Linux)
{{% for _, flag in ipairs(LINUX_LDFLAGS) do %}}
LDFLAGS += {{%= flag %}}
{{% end %}}
endif
{{% end %}}
{{% if #DARWIN_LDFLAGS > 0 then %}}
ifeq ($(UNAME_S), Darwin)
{{% for _, flag in ipairs(DARWIN_LDFLAGS) do %}}
LDFLAGS += {{%= flag %}}
{{% end %}}
endif
{{% end %}}

{{% if #LIBRARY_DIR > 0 then %}}
#需要附加link库目录
{{% for _, lib_dir in ipairs(LIBRARY_DIR) do %}}
LDFLAGS += -L{{%= lib_dir %}}
{{% end %}}
{{% end %}}
{{% if #LINUX_LIBRARY_DIR > 0 then %}}
ifeq ($(UNAME_S), Linux)
{{% for _, lib_dir in ipairs(LINUX_LIBRARY_DIR) do %}}
LDFLAGS += -L{{%= lib_dir %}}
{{% end %}}
endif
{{% end %}}
{{% if #DARWIN_LIBRARY_DIR > 0 then %}}
ifeq ($(UNAME_S), Darwin)
{{% for _, lib_dir in ipairs(DARWIN_LIBRARY_DIR) do %}}
LDFLAGS += -L{{%= lib_dir %}}
{{% end %}}
endif
{{% end %}}

#需要连接的库文件
LIBS =
ifneq ($(UNAME_S), Darwin)
{{% if MIMALLOC and MIMALLOC_DIR then %}}
#是否启用mimalloc库
LIBS += -lmimalloc
MYCFLAGS += -I$(SOLUTION_DIR){{%= MIMALLOC_DIR %}} -include ../../mimalloc-ex.h
{{% end %}}
endif
#自定义库
{{% if #LIBS > 0 then %}}
{{% for _, lib in ipairs(LIBS) do %}}
LIBS += -l{{%= lib %}}
{{% end %}}
{{% end %}}
{{% if #LINUX_LIBS > 0 then %}}
ifeq ($(UNAME_S), Linux)
{{% for _, lib in ipairs(LINUX_LIBS) do %}}
LIBS += -l{{%= lib %}}
{{% end %}}
endif
{{% end %}}
{{% if #DARWIN_LIBS > 0 then %}}
ifeq ($(UNAME_S), Darwin)
{{% for _, lib in ipairs(DARWIN_LIBS) do %}}
LIBS += -l{{%= lib %}}
{{% end %}}
endif
{{% end %}}
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

{{% if PROJECT_TYPE ~= "exe" then %}}
#目标文件前缀，定义则.so和.a加lib前缀，否则不加
{{% if LIB_PREFIX then %}}
PROJECT_PREFIX = lib
{{% else %}}
PROJECT_PREFIX =
{{% end %}}
{{% end %}}

#目标定义
{{% if PROJECT_TYPE == "static" then %}}
TARGET_DIR = $(SOLUTION_DIR){{%= DST_LIB_DIR %}}
TARGET_STATIC =  $(TARGET_DIR)/$(PROJECT_PREFIX)$(TARGET_NAME).a
MYCFLAGS += -fPIC
{{% elseif PROJECT_TYPE == "dynamic" then %}}
MYCFLAGS += -fPIC
TARGET_DIR = $(SOLUTION_DIR){{%= DST_DIR %}}
TARGET_DYNAMIC =  $(TARGET_DIR)/$(PROJECT_PREFIX)$(TARGET_NAME).so
#soname
ifeq ($(UNAME_S), Linux)
LDFLAGS += -Wl,-soname,$(PROJECT_PREFIX)$(TARGET_NAME).so
endif
#install_name
ifeq ($(UNAME_S), Darwin)
LDFLAGS += -Wl,-install_name,$(PROJECT_PREFIX)$(TARGET_NAME).so
endif
{{% else %}}
TARGET_DIR = $(SOLUTION_DIR){{%= DST_DIR %}}
TARGET_EXECUTE = $(TARGET_DIR)/$(TARGET_NAME)
{{% end %}}

#link添加.so目录
LDFLAGS += -L$(SOLUTION_DIR){{%= DST_DIR %}}
LDFLAGS += -L$(SOLUTION_DIR){{%= DST_LIB_DIR %}}

#自动生成目标
SOURCES =
{{% local TEMPS, SRC_GROUPS = {}, {} %}}
{{% local ARGS = {RECURSION = RECURSION, OBJS = OBJS, EXCLUDE_FILE = EXCLUDE_FILE } %}}
{{% local _, CSOURCES = COLLECT_SOURCES(WORK_DIR, SRC_DIRS, ARGS) %}}
{{% for _, CSRC in ipairs(CSOURCES) do %}}
{{% local fmtsrc = string.gsub(CSRC[1], '\\', '/') %}}
SOURCES += {{%= fmtsrc %}}
{{% TEMPS[CSRC[2]] = true %}}
{{% end %}}
{{% for CSRC in pairs(TEMPS) do %}}
{{% SRC_GROUPS[#SRC_GROUPS+1] = CSRC %}}
{{% end %}}

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

{{% if PROJECT_TYPE == "static" then %}}
$(TARGET_STATIC) : $(OBJS)
	ar rcs $@ $(OBJS)
	ranlib $@

#target伪目标
target : $(TARGET_STATIC)
{{% end %}}
{{% if PROJECT_TYPE == "dynamic" then %}}
$(TARGET_DYNAMIC) : $(OBJS)
	$(CC) -o $@ -shared $(OBJS) $(LDFLAGS) $(LIBS)

#target伪目标
target : $(TARGET_DYNAMIC)
{{% end %}}
{{% if PROJECT_TYPE == "exe" then %}}
$(TARGET_EXECUTE) : $(OBJS)
	$(CC) -o $@  $(OBJS) $(LDFLAGS) $(LIBS)

#target伪目标
target : $(TARGET_EXECUTE)
{{% end %}}

#clean伪目标
clean :
	rm -rf $(INT_DIR)

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(TARGET_DIR)
{{% table.sort(SRC_GROUPS, function(a, b) return a < b end) %}}
{{% for _, CSRC in ipairs(SRC_GROUPS) do %}}
{{% local fmtsub_dir = string.gsub(CSRC, '\\', '/') %}}
	mkdir -p $(INT_DIR)/{{%= fmtsub_dir %}}
{{% end %}}
{{% for _, pre_cmd in ipairs(NWINDOWS_PREBUILDS) do %}}
	{{%= pre_cmd %}}
{{% end %}}

#后编译
post_build:
{{% for _, post_cmd in ipairs(NWINDOWS_POSTBUILDS) do %}}
	{{%= post_cmd %}}
{{% end %}}
