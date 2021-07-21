empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."

CUR_DIR = $(shell pwd)/

.PHONY: clean lua luna ext http webclient luabus quanta

all: clean lua luna ext http webclient luabus quanta

proj: lua luna ext http webclient luabus quanta

clean:
	rm -rf temp;

lua:
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lualib.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f luac.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lua.mak;

ext:
	cd extend/lfs; make SOLUTION_DIR=$(CUR_DIR) -f lfs.mak;
	cd extend/pbc; make SOLUTION_DIR=$(CUR_DIR) -f pbc.mak;
	cd extend/bson; make SOLUTION_DIR=$(CUR_DIR) -f bson.mak;
	cd extend/lpeg; make SOLUTION_DIR=$(CUR_DIR) -f lpeg.mak;
	cd extend/lnet; make SOLUTION_DIR=$(CUR_DIR) -f lnet.mak;
	cd extend/mongo; make SOLUTION_DIR=$(CUR_DIR) -f mongo.mak;
	cd extend/lcrypt; make SOLUTION_DIR=$(CUR_DIR) -f lcrypt.mak;
	cd extend/luacjson; make SOLUTION_DIR=$(CUR_DIR) -f luacjson.mak;
	cd extend/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;

http:
	cd extend/luahttp; make -f luahttp.mak;

luna:
	cd core/luna; make -f luna.mak;

luabus:
	cd core/luabus; make -f luabus.mak;

quanta:
	cd core/quanta; make -f quanta.mak;

webclient:
	cd extend/webclient; make -f webclient.mak;
