empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make core' && 'make server'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."
	@echo "====server is composed of dbx,session,gate,name and world. You can only compile the module you need."


.PHONY: clean lua luna luaext xlsx http bson lnet mongo luabus quanta encrypt lualog

all: clean extend luabus quanta

proj: extend luabus quanta

extend: lua luaext luna lnet mongo xlsx http webclient lualog bson encrypt

clean:
	rm -rf temp;

lua:
	cd extend/lua; make -f lua.mak; make -f luac.mak; make -f luae.mak

luaext:
	cd extend/luaext; make -f lfs.mak; make -f lpeg.mak; make -f luacjson.mak; make -f pbc.mak;

bson:
	cd extend/bson; make -f bson.mak;

http:
	cd extend/luahttp; make -f luahttp.mak;

lualog:
	cd extend/lualog; make -f lualog.mak;

lnet:
	cd extend/lnet; make -f lnet.mak;

encrypt:
	cd extend/encrypt; make -f encrypt.mak;

xlsx:
	cd extend/luaxlsx; make -f luaxlsx.mak;

mongo:
	cd extend/mongo; make -f mongo.mak;

luna:
	cd core/luna; make -f luna.mak;

luabus:
	cd core/luabus; make -f luabus.mak;

quanta:
	cd core/quanta; make -f quanta.mak;

webclient:
	cd extend/webclient; make -f webclient.mak;
