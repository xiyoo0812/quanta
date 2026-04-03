{{%
local LABEL_GROUPS = ""
for _, GROUP in pairs(GROUPS or {}) do
	if GROUP.NAME ~= IGNORE_GROUP then
		LABEL_GROUPS = GROUP.NAME .. " " .. LABEL_GROUPS
	end
end
%}}

empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make project'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."

CUR_DIR = $(shell pwd)/

.PHONY: clean all {{%= LABEL_GROUPS %}}

all:
	@start=$$(date +%s); \
	$(MAKE) clean; \
	$(MAKE) $(MAKEFLAGS) {{%= LABEL_GROUPS %}}{{%= IGNORE_GROUP %}}; \
	end=$$(date +%s); \
	duration=$$((end - start)); \
	echo "make all cost time: $$duration second"

proj:
	@start=$$(date +%s); \
	$(MAKE) clean; \
	$(MAKE) $(MAKEFLAGS) {{%= LABEL_GROUPS %}}; \
	end=$$(date +%s); \
	duration=$$((end - start)); \
	echo "make proj cost time: $$duration second"

clean:
	rm -rf temp;

{{%
for _, GROUP in pairs (GROUPS or {}) do
	local GROUPNAMES = {}
	for _, PROJECT in ipairs(GROUP.PROJECTS or {}) do
		local PDIR = string.gsub(PROJECT.DIR, '\\', '/')
		table.insert(GROUPNAMES, PROJECT.NAME)
%}}
{{%= PROJECT.FILE %}}: {{%= table.concat(PROJECT.DEPS, " ") %}}
	$(MAKE) -C {{%= PDIR %}} -f {{%= PROJECT.FILE %}}.mak SOLUTION_DIR=$(CUR_DIR)
	{{% end %}}

{{%= GROUP.NAME %}}: {{%= table.concat(GROUPNAMES, " ") %}}
.PHONY: {{%= table.concat(GROUPNAMES, " ") %}}

{{% end %}}
