
empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make project'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."

CUR_DIR = $(shell pwd)/

.PHONY: clean all project share lua extend core 

all: clean project backup

quanta: clean project 

project: share lua extend core 

clean:
	rm -rf temp;

core:
	cd core/luabus; make SOLUTION_DIR=$(CUR_DIR) -f luabus.mak;
	cd core/quanta; make SOLUTION_DIR=$(CUR_DIR) -f quanta.mak;

backup:
	cd extend/laoi; make SOLUTION_DIR=$(CUR_DIR) -f laoi.mak;
	cd extend/ldetour; make SOLUTION_DIR=$(CUR_DIR) -f ldetour.mak;
	cd extend/lmdb; make SOLUTION_DIR=$(CUR_DIR) -f lmdb.mak;
	cd extend/lsmdb; make SOLUTION_DIR=$(CUR_DIR) -f lsmdb.mak;
	cd extend/lsqlite; make SOLUTION_DIR=$(CUR_DIR) -f lsqlite.mak;
	cd extend/ltoml; make SOLUTION_DIR=$(CUR_DIR) -f ltoml.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f luac.mak;
	cd extend/luaxml; make SOLUTION_DIR=$(CUR_DIR) -f luaxml.mak;
	cd extend/luazip; make SOLUTION_DIR=$(CUR_DIR) -f luazip.mak;
	cd extend/lunqlite; make SOLUTION_DIR=$(CUR_DIR) -f lunqlite.mak;
	cd extend/lyaml; make SOLUTION_DIR=$(CUR_DIR) -f lyaml.mak;

extend:
	cd extend/lbson; make SOLUTION_DIR=$(CUR_DIR) -f lbson.mak;
	cd extend/lcodec; make SOLUTION_DIR=$(CUR_DIR) -f lcodec.mak;
	cd extend/ljson; make SOLUTION_DIR=$(CUR_DIR) -f ljson.mak;
	cd extend/lprofile; make SOLUTION_DIR=$(CUR_DIR) -f lprofile.mak;
	cd extend/lstdfs; make SOLUTION_DIR=$(CUR_DIR) -f lstdfs.mak;
	cd extend/ltimer; make SOLUTION_DIR=$(CUR_DIR) -f ltimer.mak;
	cd extend/luacsv; make SOLUTION_DIR=$(CUR_DIR) -f luacsv.mak;
	cd extend/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;
	cd extend/luapb; make SOLUTION_DIR=$(CUR_DIR) -f luapb.mak;
	cd extend/luassl; make SOLUTION_DIR=$(CUR_DIR) -f luassl.mak;
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;
	cd extend/lworker; make SOLUTION_DIR=$(CUR_DIR) -f lworker.mak;

lua:
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lualib.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lua.mak;

share:
	cd extend/mimalloc; make SOLUTION_DIR=$(CUR_DIR) -f mimalloc.mak;

