empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."


.PHONY: clean lua luna lpeg luacjson luahttp pbc bson mongo luabus quanta


all: clean lua luna lpeg luacjson luahttp pbc bson mongo luabus quanta

proj: lua luna lpeg luacjson luahttp pbc bson mongo luabus quanta

clean:
	rm -rf temp;

lua:
	cd extend/lua; make -f lua.mak; make -f luac.mak;

lpeg:
	cd extend/lpeg; make -f lpeg.mak;

luacjson:
	cd extend/luacjson; make -f luacjson.mak;

luahttp:
	cd extend/luahttp; make -f luahttp.mak;

pbc:
	cd extend/pbc; make -f pbc.mak;

mongo:
	cd extend/mongo; make -f bson.mak;

bson:
	cd extend/bson; make -f bson.mak;

luna:
	cd core/luna; make -f luna.mak;

luabus:
	cd core/luabus; make -f luabus.mak;

quanta:
	cd core/quanta; make -f quanta.mak;
