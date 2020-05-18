
#定义基础的编译选项
CC= gcc
CX= c++
CFLAGS= -O2 -Wall -Wno-deprecated -Wextra $(SYSCFLAGS) $(MYCFLAGS)
CXXFLAGS= -O2 -Wall -Wno-deprecated -Wextra $(SYSCFLAGS) $(MYCFLAGS)
LDFLAGS= $(SYSLDFLAGS) $(MYLDFLAGS)
LIBS= -lm $(MYLIBS) $(SYSLIBS) 

#定义系统的编译选项
SYSCFLAGS= -Wno-unknown-pragmas
SYSLDFLAGS=
SYSLIBS= -Wl,-E -ldl -lreadline

#自定义的编译选项
ifndef MYCFLAGS
MYCFLAGS=
endif
ifndef MYLDFLAGS
MYLDFLAGS=
endif
ifndef MYLIBS
MYLIBS=
endif

#编译器版本
#STDC_EX = -std=c++11/-std=gnu99
ifdef STDC_EX
CXXFLAGS += $(STDC_EX)
endif

MYLIBS += -lstdc++

#源代码目录
ifndef SRC_DIR
SRC_DIR = ./src
endif

#临时文件目录
ifndef INT_DIR
INT_DIR = ../../temp/$(PROJECT_NAME)
endif

#目标目录
ifdef _LIB
TARGET_DIR = ../../lib
else
TARGET_DIR = ../../bin
MYCFLAGS += -fPIC
endif

#目标名
ifndef TARGET_NAME
TARGET_NAME = $(PROJECT_NAME)
endif

#添加目录
MYLDFLAGS += -L$(TARGET_DIR)

#输出文件名前缀
ifdef PROJECT_NO_PREFIX
PROJECT_PREFIX=
else
PROJECT_PREFIX=lib
endif

#确定输出文件名
ifeq ($(PROJECT_TYPE), lib)
ifdef _LIB
TARGET = $(PROJECT_PREFIX)$(TARGET_NAME).a
else
TARGET = $(PROJECT_PREFIX)$(TARGET_NAME).so
endif
else
TARGET = $(TARGET_NAME)
endif

#排除编译文件
ifndef EXCLUDE_FILE
EXCLUDE_FILE=
endif

#若没有指定源文件列表则把 SRC_DIR 目录下的所有源文件作为要编译的文件列表
ifndef MYOBJS
MYOBJS = $(patsubst $(SRC_DIR)/%.cpp, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE_FILE), $(wildcard $(SRC_DIR)/*.cpp)))
MYOBJS += $(patsubst $(SRC_DIR)/%.c, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE_FILE), $(wildcard $(SRC_DIR)/*.c)))
MYOBJS += $(patsubst $(SRC_DIR)/%.cc, $(INT_DIR)/%.o, $(filter-out $(EXCLUDE_FILE), $(wildcard $(SRC_DIR)/*.cc)))
endif

#输出目标
TARGET_PATH = $(TARGET_DIR)/$(TARGET)

#根据PROJECT_TYPE的值产生不同的目标文件
ifeq ($(PROJECT_TYPE), lib)
ifdef _LIB
$(TARGET_PATH) : $(MYOBJS)
	ar rcs $@ $(MYOBJS)
	ranlib $@
else
$(TARGET_PATH) : $(MYOBJS)
	$(CX) -o $@ -shared $(MYOBJS) $(LDFLAGS) $(LIBS) 
endif
else
$(TARGET_PATH) : $(MYOBJS)
	$(CX) -o $@  $(MYOBJS) $(LDFLAGS) $(LIBS) 
endif

# 编译所有源文件
$(INT_DIR)/%.o : $(SRC_DIR)/%.cpp
	$(CX) $(CXXFLAGS) -c $< -o $@
	
$(INT_DIR)/%.o : $(SRC_DIR)/%.cc
	$(CX) $(CXXFLAGS) -c $< -o $@

$(INT_DIR)/%.o : $(SRC_DIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

#target伪目标
target : $(TARGET_PATH)

#clean伪目标
clean : 
	rm -rf $(INT_DIR)
