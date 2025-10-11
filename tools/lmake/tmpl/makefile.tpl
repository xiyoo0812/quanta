{{% local LABEL_GROUPS, SORT_GROUPS = "", {} %}}
{{% for _, GROUP in pairs(GROUPS or {}) do %}}
{{% table.insert(SORT_GROUPS, GROUP) %}}
{{% if GROUP.NAME ~= IGNORE_GROUP then %}}
{{% LABEL_GROUPS = GROUP.NAME .. " " .. LABEL_GROUPS %}}
{{% end %}}
{{% end %}}

empty:
	@echo "====No target! Please specify a target to make!"
	@echo "====If you want to compile all targets, use 'make project'"
	@echo "===='make all', which shoule be the default target is unavailable for UNKNOWN reaseon now."

CUR_DIR = $(shell pwd)/

.PHONY: clean all project {{%= LABEL_GROUPS %}}

all: clean project {{%= IGNORE_GROUP %}}

{{%= SOLUTION %}}: clean project 

project: {{%= LABEL_GROUPS %}}

clean:
	rm -rf temp;

{{% for _, GROUP in pairs(SORT_GROUPS or {}) do %}}
{{%= GROUP.NAME %}}:
{{% for _, PROJECT in ipairs(GROUP.PROJECTS or {}) do %}}
	{{% local fmtname = string.gsub(PROJECT.DIR, '\\', '/') %}}
	cd {{%= fmtname %}}; make SOLUTION_DIR=$(CUR_DIR) -f {{%= PROJECT.FILE %}}.mak;
{{% end %}}

{{% end %}}
