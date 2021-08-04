empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."

CUR_DIR = $(shell pwd)/

.PHONY: clean lua luna ext luabus quanta

all: clean lua luna ext luabus quanta

proj: lua luna ext luabus quanta

clean:
	rm -rf temp;

lua:
	cd extend/luaext/lua; make SOLUTION_DIR=$(CUR_DIR) -f lualib.mak;
	cd extend/luaext/lua; make SOLUTION_DIR=$(CUR_DIR) -f luac.mak;
	cd extend/luaext/lua; make SOLUTION_DIR=$(CUR_DIR) -f lua.mak;

ext:
	cd extend/luaext/lfs; make SOLUTION_DIR=$(CUR_DIR) -f lfs.mak;
	cd extend/luaext/pbc; make SOLUTION_DIR=$(CUR_DIR) -f pbc.mak;
	cd extend/luaext/bson; make SOLUTION_DIR=$(CUR_DIR) -f bson.mak;
	cd extend/luaext/lpeg; make SOLUTION_DIR=$(CUR_DIR) -f lpeg.mak;
	cd extend/luaext/lnet; make SOLUTION_DIR=$(CUR_DIR) -f lnet.mak;
	cd extend/luaext/mongo; make SOLUTION_DIR=$(CUR_DIR) -f mongo.mak;
	cd extend/luaext/lhttp; make SOLUTION_DIR=$(CUR_DIR) -f lhttp.mak;
	cd extend/luaext/lcurl; make SOLUTION_DIR=$(CUR_DIR) -f lcurl.mak;
	cd extend/luaext/lcrypt; make SOLUTION_DIR=$(CUR_DIR) -f lcrypt.mak;
	cd extend/luaext/lcjson; make SOLUTION_DIR=$(CUR_DIR) -f lcjson.mak;
	cd extend/luaext/ltimer; make SOLUTION_DIR=$(CUR_DIR) -f ltimer.mak;
	cd extend/luaext/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;
	cd extend/luaext/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;

luna:
	cd core/luna; make SOLUTION_DIR=$(CUR_DIR) -f luna.mak;

luabus:
	cd core/luabus; make SOLUTION_DIR=$(CUR_DIR) -f luabus.mak;

quanta:
	cd core/quanta; make SOLUTION_DIR=$(CUR_DIR) -f quanta.mak;
