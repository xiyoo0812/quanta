#工程名字
PROJECT_NAME = luatls

#目标名字
TARGET_NAME = luatls

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

#c标准库版本
#gnu99/gnu11/gnu17
STDC = -std=gnu99

#c++标准库版本
#c++11/c++14/c++17/c++20/c++23
STDCPP = -std=c++20

#需要的include目录
MYCFLAGS += -I./src/include
MYCFLAGS += -I../lua/lua
MYCFLAGS += -I../luakit/include

#需要定义的选项

#LDFLAGS
LDFLAGS =


#需要连接的库文件
LIBS =
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
SOURCES += src/extend/crc.c
SOURCES += src/extend/xxtea.c
SOURCES += src/library/aes.c
SOURCES += src/library/aesce.c
SOURCES += src/library/aesni.c
SOURCES += src/library/aria.c
SOURCES += src/library/asn1parse.c
SOURCES += src/library/asn1write.c
SOURCES += src/library/base64.c
SOURCES += src/library/bignum.c
SOURCES += src/library/bignum_core.c
SOURCES += src/library/bignum_mod.c
SOURCES += src/library/bignum_mod_raw.c
SOURCES += src/library/block_cipher.c
SOURCES += src/library/camellia.c
SOURCES += src/library/ccm.c
SOURCES += src/library/chacha20.c
SOURCES += src/library/chachapoly.c
SOURCES += src/library/cipher.c
SOURCES += src/library/cipher_wrap.c
SOURCES += src/library/cmac.c
SOURCES += src/library/constant_time.c
SOURCES += src/library/ctr_drbg.c
SOURCES += src/library/debug.c
SOURCES += src/library/des.c
SOURCES += src/library/dhm.c
SOURCES += src/library/ecdh.c
SOURCES += src/library/ecdsa.c
SOURCES += src/library/ecjpake.c
SOURCES += src/library/ecp.c
SOURCES += src/library/ecp_curves.c
SOURCES += src/library/ecp_curves_new.c
SOURCES += src/library/entropy.c
SOURCES += src/library/entropy_poll.c
SOURCES += src/library/error.c
SOURCES += src/library/gcm.c
SOURCES += src/library/hkdf.c
SOURCES += src/library/hmac_drbg.c
SOURCES += src/library/lmots.c
SOURCES += src/library/lms.c
SOURCES += src/library/md.c
SOURCES += src/library/md5.c
SOURCES += src/library/memory_buffer_alloc.c
SOURCES += src/library/mps_reader.c
SOURCES += src/library/mps_trace.c
SOURCES += src/library/net_sockets.c
SOURCES += src/library/nist_kw.c
SOURCES += src/library/oid.c
SOURCES += src/library/padlock.c
SOURCES += src/library/pem.c
SOURCES += src/library/pk.c
SOURCES += src/library/pk_ecc.c
SOURCES += src/library/pk_wrap.c
SOURCES += src/library/pkcs12.c
SOURCES += src/library/pkcs5.c
SOURCES += src/library/pkcs7.c
SOURCES += src/library/pkparse.c
SOURCES += src/library/pkwrite.c
SOURCES += src/library/platform.c
SOURCES += src/library/platform_util.c
SOURCES += src/library/poly1305.c
SOURCES += src/library/psa_crypto.c
SOURCES += src/library/psa_crypto_aead.c
SOURCES += src/library/psa_crypto_cipher.c
SOURCES += src/library/psa_crypto_client.c
SOURCES += src/library/psa_crypto_driver_wrappers_no_static.c
SOURCES += src/library/psa_crypto_ecp.c
SOURCES += src/library/psa_crypto_ffdh.c
SOURCES += src/library/psa_crypto_hash.c
SOURCES += src/library/psa_crypto_mac.c
SOURCES += src/library/psa_crypto_pake.c
SOURCES += src/library/psa_crypto_rsa.c
SOURCES += src/library/psa_crypto_se.c
SOURCES += src/library/psa_crypto_slot_management.c
SOURCES += src/library/psa_crypto_storage.c
SOURCES += src/library/psa_its_file.c
SOURCES += src/library/psa_util.c
SOURCES += src/library/ripemd160.c
SOURCES += src/library/rsa.c
SOURCES += src/library/rsa_alt_helpers.c
SOURCES += src/library/sha1.c
SOURCES += src/library/sha256.c
SOURCES += src/library/sha3.c
SOURCES += src/library/sha512.c
SOURCES += src/library/ssl_cache.c
SOURCES += src/library/ssl_ciphersuites.c
SOURCES += src/library/ssl_client.c
SOURCES += src/library/ssl_cookie.c
SOURCES += src/library/ssl_debug_helpers_generated.c
SOURCES += src/library/ssl_msg.c
SOURCES += src/library/ssl_ticket.c
SOURCES += src/library/ssl_tls.c
SOURCES += src/library/ssl_tls12_client.c
SOURCES += src/library/ssl_tls12_server.c
SOURCES += src/library/ssl_tls13_client.c
SOURCES += src/library/ssl_tls13_generic.c
SOURCES += src/library/ssl_tls13_keys.c
SOURCES += src/library/ssl_tls13_server.c
SOURCES += src/library/threading.c
SOURCES += src/library/timing.c
SOURCES += src/library/version.c
SOURCES += src/library/version_features.c
SOURCES += src/library/x509.c
SOURCES += src/library/x509_create.c
SOURCES += src/library/x509_crl.c
SOURCES += src/library/x509_crt.c
SOURCES += src/library/x509_csr.c
SOURCES += src/library/x509write.c
SOURCES += src/library/x509write_crt.c
SOURCES += src/library/x509write_csr.c
SOURCES += src/luatls.cpp

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
	mkdir -p $(INT_DIR)/src/extend
	mkdir -p $(INT_DIR)/src/library

#后编译
post_build:
