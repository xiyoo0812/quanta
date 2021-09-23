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
	cd core/luna; make SOLUTION_DIR=$(CUR_DIR) -f luna.mak;
	cd core/luabus; make SOLUTION_DIR=$(CUR_DIR) -f luabus.mak;
	cd core/quanta; make SOLUTION_DIR=$(CUR_DIR) -f quanta.mak;

lua:
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lualib.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lua.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f luac.mak;

luaext:
	cd extend/bson; make SOLUTION_DIR=$(CUR_DIR) -f bson.mak;
	cd extend/lbuffer; make SOLUTION_DIR=$(CUR_DIR) -f lbuffer.mak;
	cd extend/lcjson; make SOLUTION_DIR=$(CUR_DIR) -f lcjson.mak;
	cd extend/lcrypt; make SOLUTION_DIR=$(CUR_DIR) -f lcrypt.mak;
	cd extend/lcurl; make SOLUTION_DIR=$(CUR_DIR) -f lcurl.mak;
	cd extend/lhttp; make SOLUTION_DIR=$(CUR_DIR) -f lhttp.mak;
	cd extend/lnet; make SOLUTION_DIR=$(CUR_DIR) -f lnet.mak;
	cd extend/lstdfs; make SOLUTION_DIR=$(CUR_DIR) -f lstdfs.mak;
	cd extend/ltimer; make SOLUTION_DIR=$(CUR_DIR) -f ltimer.mak;
	cd extend/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;
	cd extend/mongo; make SOLUTION_DIR=$(CUR_DIR) -f mongo.mak;
	cd extend/pbc; make SOLUTION_DIR=$(CUR_DIR) -f pbc.mak;

share:
	cd extend/mimalloc; make SOLUTION_DIR=$(CUR_DIR) -f mimalloc.mak;

