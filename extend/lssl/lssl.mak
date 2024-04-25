#工程名字
PROJECT_NAME = lssl

#目标名字
TARGET_NAME = lssl

#系统环境
UNAME_S = $(shell uname -s)

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#CFLAG
MYCFLAGS =

#需要定义的FLAG
MYCFLAGS += -Wsign-compare
MYCFLAGS += -Wno-sign-compare
MYCFLAGS += -Wno-unused-variable
MYCFLAGS += -Wno-unused-parameter
MYCFLAGS += -Wno-unused-but-set-variable
MYCFLAGS += -Wno-unused-but-set-parameter
MYCFLAGS += -Wno-unknown-pragmas
MYCFLAGS += -Wno-implicit-fallthrough

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
MYCFLAGS += -DWOLFSSL_LIB
MYCFLAGS += -DWOLFSSL_SRTP
MYCFLAGS += -DWOLFSSL_NO_SOCK
MYCFLAGS += -DWOLFSSL_USER_IO
MYCFLAGS += -DWOLFSSL_USER_SETTINGS
ifeq ($(UNAME_S), Darwin)
MYCFLAGS += -DWOLFSSL_APPLE_NATIVE_CERT_VALIDATION
endif

#LDFLAGS
LDFLAGS =
ifeq ($(UNAME_S), Darwin)
LDFLAGS += -framework CoreFoundation
LDFLAGS += -framework Security
endif


#源文件路径
SRC_DIR = src

#需要排除的源文件,目录基于$(SRC_DIR)
EXCLUDE =
EXCLUDE += $(SRC_DIR)/src\ssl_bn.c
EXCLUDE += $(SRC_DIR)/src\ssl_misc.c
EXCLUDE += $(SRC_DIR)/src\ssl_asn1.c
EXCLUDE += $(SRC_DIR)/src\ssl_crypto.c
EXCLUDE += $(SRC_DIR)/src\ssl_certman.c
EXCLUDE += $(SRC_DIR)/wolfcrypt\src\evp.c
EXCLUDE += $(SRC_DIR)/wolfcrypt\src\misc.c
EXCLUDE += $(SRC_DIR)/src\x509_str.c
EXCLUDE += $(SRC_DIR)/src\x509.c
EXCLUDE += $(SRC_DIR)/src\conf.c
EXCLUDE += $(SRC_DIR)/src\bio.c
EXCLUDE += $(SRC_DIR)/src\pk.c

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
CFLAGS = -g -O2 -Wall -Wno-deprecated -Wextra $(STDC) $(MYCFLAGS)
CXXFLAGS = -g -O2 -Wall -Wno-deprecated -Wextra $(STDCPP) $(MYCFLAGS)

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
OBJS =
#子目录
OBJS += $(patsubst $(SRC_DIR)/src/%.c, $(INT_DIR)/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/src/*.c)))
OBJS += $(patsubst $(SRC_DIR)/src/%.m, $(INT_DIR)/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/src/*.m)))
OBJS += $(patsubst $(SRC_DIR)/src/%.cc, $(INT_DIR)/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/src/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/src/%.cpp, $(INT_DIR)/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/src/*.cpp)))
#子目录
OBJS += $(patsubst $(SRC_DIR)/ssl/%.c, $(INT_DIR)/ssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/ssl/*.c)))
OBJS += $(patsubst $(SRC_DIR)/ssl/%.m, $(INT_DIR)/ssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/ssl/*.m)))
OBJS += $(patsubst $(SRC_DIR)/ssl/%.cc, $(INT_DIR)/ssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/ssl/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/ssl/%.cpp, $(INT_DIR)/ssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/ssl/*.cpp)))
#子目录
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/%.c, $(INT_DIR)/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/*.c)))
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/%.m, $(INT_DIR)/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/*.m)))
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/%.cc, $(INT_DIR)/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/%.cpp, $(INT_DIR)/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/*.cpp)))
#子目录
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/src/%.c, $(INT_DIR)/wolfcrypt/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/src/*.c)))
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/src/%.m, $(INT_DIR)/wolfcrypt/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/src/*.m)))
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/src/%.cc, $(INT_DIR)/wolfcrypt/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/src/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/wolfcrypt/src/%.cpp, $(INT_DIR)/wolfcrypt/src/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfcrypt/src/*.cpp)))
#子目录
OBJS += $(patsubst $(SRC_DIR)/wolfssl/%.c, $(INT_DIR)/wolfssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/*.c)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/%.m, $(INT_DIR)/wolfssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/*.m)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/%.cc, $(INT_DIR)/wolfssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/%.cpp, $(INT_DIR)/wolfssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/*.cpp)))
#子目录
OBJS += $(patsubst $(SRC_DIR)/wolfssl/openssl/%.c, $(INT_DIR)/wolfssl/openssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/openssl/*.c)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/openssl/%.m, $(INT_DIR)/wolfssl/openssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/openssl/*.m)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/openssl/%.cc, $(INT_DIR)/wolfssl/openssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/openssl/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/openssl/%.cpp, $(INT_DIR)/wolfssl/openssl/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/openssl/*.cpp)))
#子目录
OBJS += $(patsubst $(SRC_DIR)/wolfssl/wolfcrypt/%.c, $(INT_DIR)/wolfssl/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/wolfcrypt/*.c)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/wolfcrypt/%.m, $(INT_DIR)/wolfssl/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/wolfcrypt/*.m)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/wolfcrypt/%.cc, $(INT_DIR)/wolfssl/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/wolfcrypt/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/wolfssl/wolfcrypt/%.cpp, $(INT_DIR)/wolfssl/wolfcrypt/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/wolfssl/wolfcrypt/*.cpp)))
#根目录
OBJS += $(patsubst $(SRC_DIR)/%.c, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/*.c)))
OBJS += $(patsubst $(SRC_DIR)/%.m, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/*.m)))
OBJS += $(patsubst $(SRC_DIR)/%.cc, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/*.cc)))
OBJS += $(patsubst $(SRC_DIR)/%.cpp, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE), $(wildcard $(SRC_DIR)/*.cpp)))

# 编译所有源文件
$(INT_DIR)/%.o : $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@
$(INT_DIR)/%.o : $(SRC_DIR)/%.m
	$(CC) $(CFLAGS) -c $< -o $@
$(INT_DIR)/%.o : $(SRC_DIR)/%.cc
	$(CX) $(CXXFLAGS) -c $< -o $@
$(INT_DIR)/%.o : $(SRC_DIR)/%.cpp
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
	mkdir -p $(INT_DIR)/ssl
	mkdir -p $(INT_DIR)/wolfcrypt
	mkdir -p $(INT_DIR)/wolfcrypt/src
	mkdir -p $(INT_DIR)/wolfssl
	mkdir -p $(INT_DIR)/wolfssl/openssl
	mkdir -p $(INT_DIR)/wolfssl/wolfcrypt

#后编译
post_build:
