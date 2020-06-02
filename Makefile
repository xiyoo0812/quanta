empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."


.PHONY: clean lua luna lpeg cjson xlsx http pbc bson mongo luabus quanta sproto proto encrypt

all: clean core extend proto quanta

proj: core extend quanta

core: luna luabus

extend: lua lfs luna lpeg cjson mongo xlsx http webclient

proto: pbc bson sproto encrypt

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

cjson:
	cd extend/luacjson; make -f luacjson.mak;

http:
	cd extend/luahttp; make -f luahttp.mak;

encrypt:
	cd extend/encrypt; make -f encrypt.mak;

xlsx:
	cd extend/luaxlsx; make -f luaxlsx.mak;

mongo:
	cd extend/mongo; make -f mongo.mak;
	cd extend/msocket; make -f msocket.mak;

luna:
	cd core/luna; make -f luna.mak;

luabus:
	cd core/luabus; make -f luabus.mak;

quanta:
	cd core/quanta; make -f quanta.mak;

webclient:
	cd extend/webclient; make -f webclient.mak;
