empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."

CUR_DIR = $(shell pwd)/

.PHONY: clean all server  share lua luaext core

all: clean server 

server:  share lua luaext core

clean:
	rm -rf temp;

core:
	cd core/quanta; make SOLUTION_DIR=$(CUR_DIR) -f quanta.mak;

lua:
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lualib.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lua.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f luac.mak;

luaext:
	cd extend/laoi; make SOLUTION_DIR=$(CUR_DIR) -f laoi.mak;
	cd extend/lbson; make SOLUTION_DIR=$(CUR_DIR) -f lbson.mak;
	cd extend/lcodec; make SOLUTION_DIR=$(CUR_DIR) -f lcodec.mak;
	cd extend/lcrypt; make SOLUTION_DIR=$(CUR_DIR) -f lcrypt.mak;
	cd extend/lcurl; make SOLUTION_DIR=$(CUR_DIR) -f lcurl.mak;
	cd extend/ldetour; make SOLUTION_DIR=$(CUR_DIR) -f ldetour.mak;
	cd extend/lhttp; make SOLUTION_DIR=$(CUR_DIR) -f lhttp.mak;
	cd extend/ljson; make SOLUTION_DIR=$(CUR_DIR) -f ljson.mak;
	cd extend/lstdfs; make SOLUTION_DIR=$(CUR_DIR) -f lstdfs.mak;
	cd extend/ltimer; make SOLUTION_DIR=$(CUR_DIR) -f ltimer.mak;
	cd extend/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;
	cd extend/lworker; make SOLUTION_DIR=$(CUR_DIR) -f lworker.mak;
	cd extend/protobuf; make SOLUTION_DIR=$(CUR_DIR) -f lua-protobuf.mak;

share:
	cd extend/mimalloc; make SOLUTION_DIR=$(CUR_DIR) -f mimalloc.mak;

