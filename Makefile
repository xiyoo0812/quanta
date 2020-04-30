empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."


.PHONY: clean lua luna lpeg luacjson luahttp pbc bson mongo luabus quanta sproto proto

all: clean core extend

proj: core extend

core: luna luabus quanta luahttp

extend: lua lfs luna lpeg luacjson proto mongo

proto: pbc bson sproto

clean:
	rm -rf temp;

lua:
	cd extend/lua; make -f lua.mak; make -f luac.mak;

pbc:
	cd extend/pbc; make -f pbc.mak;
	
sproto:
	cd extend/sproto; make -f sproto.mak;

bson:
	cd extend/bson; make -f bson.mak;

lpeg:
	cd extend/lpeg; make -f lpeg.mak;

lfs:
	cd extend/lfs; make -f lfs.mak;

luacjson:
	cd extend/luacjson; make -f luacjson.mak;

luahttp:
	cd extend/luahttp; make -f luahttp.mak;

mongo:
	cd extend/mongo; make -f bson.mak;

luna:
	cd core/luna; make -f luna.mak;

luabus:
	cd core/luabus; make -f luabus.mak;

quanta:
	cd core/quanta; make -f quanta.mak;
