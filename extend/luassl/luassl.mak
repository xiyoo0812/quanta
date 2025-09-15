#工程名字
PROJECT_NAME = luassl

#目标名字
TARGET_NAME = luassl

#系统环境
UNAME_S = $(shell uname -s)

#伪目标
.PHONY: clean all target pre_build post_build
all : pre_build target post_build

#CFLAG
MYCFLAGS =

#需要定义的FLAG
MYCFLAGS += -Wno-sign-compare
MYCFLAGS += -Wno-unused-function
MYCFLAGS += -Wno-unused-variable
MYCFLAGS += -Wno-unused-parameter
MYCFLAGS += -Wno-unused-but-set-variable
MYCFLAGS += -Wno-unused-but-set-parameter
MYCFLAGS += -Wno-implicit-function-declaration

#c标准库版本
#gnu99/gnu11/gnu17
STDC = -std=gnu99

#c++标准库版本
#c++11/c++14/c++17/c++20/c++23
STDCPP = -std=c++20

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
SOURCES += src/src/crl.c
SOURCES += src/src/dtls.c
SOURCES += src/src/dtls13.c
SOURCES += src/src/internal.c
SOURCES += src/src/keys.c
SOURCES += src/src/ocsp.c
SOURCES += src/src/quic.c
SOURCES += src/src/sniffer.c
SOURCES += src/src/ssl.c
SOURCES += src/src/tls.c
SOURCES += src/src/tls13.c
SOURCES += src/src/wolfio.c
SOURCES += src/ssl/crc.c
SOURCES += src/ssl/hmac_sha.c
SOURCES += src/ssl/luassl.cpp
SOURCES += src/ssl/xxtea.c
SOURCES += src/wolfcrypt/src/aes.c
SOURCES += src/wolfcrypt/src/arc4.c
SOURCES += src/wolfcrypt/src/asm.c
SOURCES += src/wolfcrypt/src/asn.c
SOURCES += src/wolfcrypt/src/blake2b.c
SOURCES += src/wolfcrypt/src/blake2s.c
SOURCES += src/wolfcrypt/src/camellia.c
SOURCES += src/wolfcrypt/src/chacha.c
SOURCES += src/wolfcrypt/src/chacha20_poly1305.c
SOURCES += src/wolfcrypt/src/cmac.c
SOURCES += src/wolfcrypt/src/coding.c
SOURCES += src/wolfcrypt/src/compress.c
SOURCES += src/wolfcrypt/src/cpuid.c
SOURCES += src/wolfcrypt/src/cryptocb.c
SOURCES += src/wolfcrypt/src/curve25519.c
SOURCES += src/wolfcrypt/src/curve448.c
SOURCES += src/wolfcrypt/src/des3.c
SOURCES += src/wolfcrypt/src/dh.c
SOURCES += src/wolfcrypt/src/dilithium.c
SOURCES += src/wolfcrypt/src/dsa.c
SOURCES += src/wolfcrypt/src/ecc.c
SOURCES += src/wolfcrypt/src/ecc_fp.c
SOURCES += src/wolfcrypt/src/eccsi.c
SOURCES += src/wolfcrypt/src/ed25519.c
SOURCES += src/wolfcrypt/src/ed448.c
SOURCES += src/wolfcrypt/src/error.c
SOURCES += src/wolfcrypt/src/ext_kyber.c
SOURCES += src/wolfcrypt/src/ext_lms.c
SOURCES += src/wolfcrypt/src/ext_xmss.c
SOURCES += src/wolfcrypt/src/falcon.c
SOURCES += src/wolfcrypt/src/fe_448.c
SOURCES += src/wolfcrypt/src/fe_low_mem.c
SOURCES += src/wolfcrypt/src/fe_operations.c
SOURCES += src/wolfcrypt/src/ge_448.c
SOURCES += src/wolfcrypt/src/ge_low_mem.c
SOURCES += src/wolfcrypt/src/ge_operations.c
SOURCES += src/wolfcrypt/src/hash.c
SOURCES += src/wolfcrypt/src/hmac.c
SOURCES += src/wolfcrypt/src/hpke.c
SOURCES += src/wolfcrypt/src/integer.c
SOURCES += src/wolfcrypt/src/kdf.c
SOURCES += src/wolfcrypt/src/logging.c
SOURCES += src/wolfcrypt/src/md2.c
SOURCES += src/wolfcrypt/src/md4.c
SOURCES += src/wolfcrypt/src/md5.c
SOURCES += src/wolfcrypt/src/memory.c
SOURCES += src/wolfcrypt/src/pkcs12.c
SOURCES += src/wolfcrypt/src/pkcs7.c
SOURCES += src/wolfcrypt/src/poly1305.c
SOURCES += src/wolfcrypt/src/pwdbased.c
SOURCES += src/wolfcrypt/src/random.c
SOURCES += src/wolfcrypt/src/rc2.c
SOURCES += src/wolfcrypt/src/ripemd.c
SOURCES += src/wolfcrypt/src/rsa.c
SOURCES += src/wolfcrypt/src/sakke.c
SOURCES += src/wolfcrypt/src/sha.c
SOURCES += src/wolfcrypt/src/sha256.c
SOURCES += src/wolfcrypt/src/sha3.c
SOURCES += src/wolfcrypt/src/sha512.c
SOURCES += src/wolfcrypt/src/signature.c
SOURCES += src/wolfcrypt/src/siphash.c
SOURCES += src/wolfcrypt/src/sm2.c
SOURCES += src/wolfcrypt/src/sm3.c
SOURCES += src/wolfcrypt/src/sm4.c
SOURCES += src/wolfcrypt/src/sp_arm32.c
SOURCES += src/wolfcrypt/src/sp_arm64.c
SOURCES += src/wolfcrypt/src/sp_armthumb.c
SOURCES += src/wolfcrypt/src/sp_c32.c
SOURCES += src/wolfcrypt/src/sp_c64.c
SOURCES += src/wolfcrypt/src/sp_cortexm.c
SOURCES += src/wolfcrypt/src/sp_dsp32.c
SOURCES += src/wolfcrypt/src/sp_int.c
SOURCES += src/wolfcrypt/src/sp_sm2_arm32.c
SOURCES += src/wolfcrypt/src/sp_sm2_arm64.c
SOURCES += src/wolfcrypt/src/sp_sm2_armthumb.c
SOURCES += src/wolfcrypt/src/sp_sm2_c32.c
SOURCES += src/wolfcrypt/src/sp_sm2_c64.c
SOURCES += src/wolfcrypt/src/sp_sm2_cortexm.c
SOURCES += src/wolfcrypt/src/sp_sm2_x86_64.c
SOURCES += src/wolfcrypt/src/sp_x86_64.c
SOURCES += src/wolfcrypt/src/sphincs.c
SOURCES += src/wolfcrypt/src/srp.c
SOURCES += src/wolfcrypt/src/tfm.c
SOURCES += src/wolfcrypt/src/wc_dsp.c
SOURCES += src/wolfcrypt/src/wc_encrypt.c
SOURCES += src/wolfcrypt/src/wc_kyber.c
SOURCES += src/wolfcrypt/src/wc_kyber_poly.c
SOURCES += src/wolfcrypt/src/wc_lms.c
SOURCES += src/wolfcrypt/src/wc_lms_impl.c
SOURCES += src/wolfcrypt/src/wc_pkcs11.c
SOURCES += src/wolfcrypt/src/wc_port.c
SOURCES += src/wolfcrypt/src/wc_xmss.c
SOURCES += src/wolfcrypt/src/wc_xmss_impl.c
SOURCES += src/wolfcrypt/src/wolfevent.c
SOURCES += src/wolfcrypt/src/wolfmath.c

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
	mkdir -p $(INT_DIR)/src/src
	mkdir -p $(INT_DIR)/src/ssl
	mkdir -p $(INT_DIR)/src/wolfcrypt/src

#后编译
post_build:
