#工程名字
PROJECT_NAME = curl
#工程类型，可以是库(lib)或可执行程序(exe)
PROJECT_TYPE = lib

#目标文件前缀，不定义则.so和.a加lib前缀，否则不加
PROJECT_NO_PREFIX=1

#是否静态库，定义后生成.a文件，否则生成.so文件
#_STATIC=

#c99
STDC_EX= -std=gnu99

# share.mak包含了一些编译选项，在这里可以添加新的选项和include目录
MYCFLAGS = -I./ -I./src -I../openssl/include

#share.mak包含了一些链接选项，在这里可以添加新的选项和lib目录
MYLDFLAGS = -DUSE_SSLEAY -DUSE_OPENSSL -DBUILDING_LIBCURL

#share.mak包含了一些公用的库,这里加上其他所需的库
MYLIBS =

#源文件路径
SRC_DIR=./src

#需要排除的源文件
#EXCLUDE_FILE=

#目标文件，可以在这里定义，如果没有定义，share.mak会自动生成
#MYOBJS=
MYOBJS = $(patsubst $(SRC_DIR)/%.c, $(INT_DIR)/%.o, $(wildcard $(SRC_DIR)/*.c))
MYOBJS += $(patsubst $(SRC_DIR)/vauth/%.c, $(INT_DIR)/vauth/%.o, $(wildcard $(SRC_DIR)/vauth/*.c))
MYOBJS += $(patsubst $(SRC_DIR)/vquic/%.c, $(INT_DIR)/vquic/%.o, $(wildcard $(SRC_DIR)/vquic/*.c))
MYOBJS += $(patsubst $(SRC_DIR)/vssh/%.c, $(INT_DIR)/vssh/%.o, $(wildcard $(SRC_DIR)/vssh/*.c)))
MYOBJS += $(patsubst $(SRC_DIR)/vtls/%.c, $(INT_DIR)/vtls/%.o, $(wildcard $(SRC_DIR)/vtls/*.c)))

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#通用规则
include ../../share/share.mak

#预编译
pre_build:
	mkdir -p $(INT_DIR)
	mkdir -p $(INT_DIR)/vauth
	mkdir -p $(INT_DIR)/vssh
	mkdir -p $(INT_DIR)/vquic
	mkdir -p $(INT_DIR)/vtls
	mkdir -p $(TARGET_DIR)


$(INT_DIR)/vauth/%.o : $(SRC_DIR)/vauth/%.c
	$(CC) $(CXXFLAGS) -c $< -o $@

$(INT_DIR)/vssh/%.o : $(SRC_DIR)/vssh/%.c
	$(CC) $(CXXFLAGS) -c $< -o $@

$(INT_DIR)/vquic/%.o : $(SRC_DIR)/vquic/%.c
	$(CX) $(CXXFLAGS) -c $< -o $@

$(INT_DIR)/vtls/%.o : $(SRC_DIR)/vtls/%.c
	$(CC) $(CXXFLAGS) -c $< -o $@

#后编译
post_build:
