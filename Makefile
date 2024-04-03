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
	cd core/luabus; make SOLUTION_DIR=$(CUR_DIR) -f luabus.mak;
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
	cd extend/ldetour; make SOLUTION_DIR=$(CUR_DIR) -f ldetour.mak;
	cd extend/ljson; make SOLUTION_DIR=$(CUR_DIR) -f ljson.mak;
	cd extend/lmdb; make SOLUTION_DIR=$(CUR_DIR) -f lmdb.mak;
	cd extend/lsqlite; make SOLUTION_DIR=$(CUR_DIR) -f lsqlite.mak;
	cd extend/lstdfs; make SOLUTION_DIR=$(CUR_DIR) -f lstdfs.mak;
	cd extend/ltimer; make SOLUTION_DIR=$(CUR_DIR) -f ltimer.mak;
	cd extend/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;
	cd extend/luapb; make SOLUTION_DIR=$(CUR_DIR) -f luapb.mak;
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;
	cd extend/lunqlite; make SOLUTION_DIR=$(CUR_DIR) -f lunqlite.mak;
	cd extend/lworker; make SOLUTION_DIR=$(CUR_DIR) -f lworker.mak;

share:
	cd extend/mimalloc; make SOLUTION_DIR=$(CUR_DIR) -f mimalloc.mak;
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f miniz.mak;

