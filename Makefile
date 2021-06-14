empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."

CUR_DIR = $(shell pwd)/

.PHONY: clean lua luna luaext xlsx http luabus quanta encrypt lualog

all: clean extend luabus quanta

proj: extend luabus quanta

extend: lua luaext luna xlsx http webclient lualog encrypt

clean:
	rm -rf temp;

lua:
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lualib.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f luac.mak;
	cd extend/lua; make SOLUTION_DIR=$(CUR_DIR) -f lua.mak;

luaext:
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f lfs.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f pbc.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f bson.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f lpeg.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f lnet.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f mongo.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f lcrypt.mak;
	cd extend/luaext; make SOLUTION_DIR=$(CUR_DIR) -f luacjson.mak;

http:
	cd extend/luahttp; make -f luahttp.mak;

lualog:
	cd extend/lualog; make SOLUTION_DIR=$(CUR_DIR) -f lualog.mak;

xlsx:
	cd extend/luaxlsx; make SOLUTION_DIR=$(CUR_DIR) -f luaxlsx.mak;

luna:
	cd core/luna; make -f luna.mak;

luabus:
	cd core/luabus; make -f luabus.mak;

quanta:
	cd core/quanta; make -f quanta.mak;

webclient:
	cd extend/webclient; make -f webclient.mak;
