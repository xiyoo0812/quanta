
empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make project'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."

CUR_DIR = $(shell pwd)/

.PHONY: clean all luas extend core 

all:
	@start=$$(date +%s); \
	$(MAKE) clean; \
	$(MAKE) $(MAKEFLAGS) luas extend core backup; \
	end=$$(date +%s); \
	duration=$$((end - start)); \
	echo "make all cost time: $$duration second"

proj:
	@start=$$(date +%s); \
	$(MAKE) clean; \
	$(MAKE) $(MAKEFLAGS) luas extend core ; \
	end=$$(date +%s); \
	duration=$$((end - start)); \
	echo "make proj cost time: $$duration second"

clean:
	rm -rf temp;

luabus: lualib
	$(MAKE) -C core/luabus -f luabus.mak SOLUTION_DIR=$(CUR_DIR)
quanta: luabus
	$(MAKE) -C core/quanta -f quanta.mak SOLUTION_DIR=$(CUR_DIR)

core: luabus quanta
.PHONY: luabus quanta

lbson: lualib
	$(MAKE) -C extend/lbson -f lbson.mak SOLUTION_DIR=$(CUR_DIR)
lcodec: lualib
	$(MAKE) -C extend/lcodec -f lcodec.mak SOLUTION_DIR=$(CUR_DIR)
ljson: lualib
	$(MAKE) -C extend/ljson -f ljson.mak SOLUTION_DIR=$(CUR_DIR)
lprofile: lualib
	$(MAKE) -C extend/lprofile -f lprofile.mak SOLUTION_DIR=$(CUR_DIR)
lsmdb: lualib
	$(MAKE) -C extend/lsmdb -f lsmdb.mak SOLUTION_DIR=$(CUR_DIR)
lstdfs: lualib
	$(MAKE) -C extend/lstdfs -f lstdfs.mak SOLUTION_DIR=$(CUR_DIR)
ltimer: lualib
	$(MAKE) -C extend/ltimer -f ltimer.mak SOLUTION_DIR=$(CUR_DIR)
lualog: lualib
	$(MAKE) -C extend/lualog -f lualog.mak SOLUTION_DIR=$(CUR_DIR)
luapb: lualib
	$(MAKE) -C extend/luapb -f luapb.mak SOLUTION_DIR=$(CUR_DIR)
luatls: lualib
	$(MAKE) -C extend/luatls -f luatls.mak SOLUTION_DIR=$(CUR_DIR)
luaxlsx: lualib
	$(MAKE) -C extend/luaxlsx -f luaxlsx.mak SOLUTION_DIR=$(CUR_DIR)
luazip: lualib
	$(MAKE) -C extend/luazip -f luazip.mak SOLUTION_DIR=$(CUR_DIR)
lworker: lualib
	$(MAKE) -C extend/lworker -f lworker.mak SOLUTION_DIR=$(CUR_DIR)

extend: lbson lcodec ljson lprofile lsmdb lstdfs ltimer lualog luapb luatls luaxlsx luazip lworker
.PHONY: lbson lcodec ljson lprofile lsmdb lstdfs ltimer lualog luapb luatls luaxlsx luazip lworker

laoi: lualib
	$(MAKE) -C extend/laoi -f laoi.mak SOLUTION_DIR=$(CUR_DIR)
ldetour: lualib
	$(MAKE) -C extend/ldetour -f ldetour.mak SOLUTION_DIR=$(CUR_DIR)
lmdb: lualib
	$(MAKE) -C extend/lmdb -f lmdb.mak SOLUTION_DIR=$(CUR_DIR)
lsqlite: lualib
	$(MAKE) -C extend/lsqlite -f lsqlite.mak SOLUTION_DIR=$(CUR_DIR)
ltoml: lualib
	$(MAKE) -C extend/ltoml -f ltoml.mak SOLUTION_DIR=$(CUR_DIR)
luac: lualib
	$(MAKE) -C extend/lua -f luac.mak SOLUTION_DIR=$(CUR_DIR)
luacsv: lualib
	$(MAKE) -C extend/luacsv -f luacsv.mak SOLUTION_DIR=$(CUR_DIR)
luakcp: lualib
	$(MAKE) -C extend/luakcp -f luakcp.mak SOLUTION_DIR=$(CUR_DIR)
luaxml: lualib
	$(MAKE) -C extend/luaxml -f luaxml.mak SOLUTION_DIR=$(CUR_DIR)

backup: laoi ldetour lmdb lsqlite ltoml luac luacsv luakcp luaxml
.PHONY: laoi ldetour lmdb lsqlite ltoml luac luacsv luakcp luaxml

lualib: 
	$(MAKE) -C extend/lua -f lualib.mak SOLUTION_DIR=$(CUR_DIR)
lua: lualib
	$(MAKE) -C extend/lua -f lua.mak SOLUTION_DIR=$(CUR_DIR)

luas: lualib lua
.PHONY: lualib lua

