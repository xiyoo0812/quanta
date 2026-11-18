
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version {{%= MSVC_VERSION %}}
VisualStudioVersion = {{%= MSVC_VERSION_FULL %}}
MinimumVisualStudioVersion = 10.0.40219.1
{{% local ALL_PROJS, CONFIGS = {}, SOLUTION_CONFIGS %}}
{{% local ALL_GUID = GUID_NEW("@g" .. "all") %}}
Project("{2150E333-8FDC-42A3-9474-1A3956D46DE8}") = "all", "all", "{{{%= ALL_GUID %}}}"
EndProject
{{% for _, GROUP in pairs(GROUPS or {}) do %}}
{{% if GROUP.NAME ~= IGNORE_GROUP then %}}
Project("{2150E333-8FDC-42A3-9474-1A3956D46DE8}") = "{{%= XML_ESCAPE(GROUP.NAME) %}}", "{{%= XML_ESCAPE(GROUP.NAME) %}}", "{{{%= GUID_NEW("@g" .. GROUP.NAME) %}}}"
EndProject
{{% for _, PROJECT in ipairs(GROUP.PROJECTS or {}) do %}}
{{% table.insert(ALL_PROJS, PROJECT) %}}
{{% local PROJECT_DIR = XML_ESCAPE(string.gsub(PROJECT.DIR, '/', '\\')) %}}
Project("{8BC9CEB8-8B4A-11D0-8D11-00A0C91BC942}") = "{{%= XML_ESCAPE(PROJECT.NAME) %}}", "{{%= PROJECT_DIR %}}\{{%= XML_ESCAPE(PROJECT.FILE) %}}.vcxproj", "{{{%= PROJECT.GUID %}}}"
	{{% if #PROJECT.DEPS > 0 then %}}
	ProjectSection(ProjectDependencies) = postProject
	{{% for _, DEP in ipairs(PROJECT.DEPS) do %}}
		{{{%= GUID_NEW(DEP) %}}} = {{{%= GUID_NEW(DEP) %}}}
	{{% end %}}
	EndProjectSection
	{{% end %}}
EndProject
{{% end %}}
{{% end %}}
{{% end %}}
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
	{{% for _, CFG in ipairs(CONFIGS) do %}}
		{{%= CFG.NAME %}}|{{%= PLATFORM %}} = {{%= CFG.NAME %}}|{{%= PLATFORM %}}
	{{% end %}}
	EndGlobalSection
	GlobalSection(ProjectConfigurationPlatforms) = postSolution
	{{% for _, PROJ in pairs(ALL_PROJS or {}) do %}}
	{{% for _, CFG in ipairs(CONFIGS) do %}}
		{{{%= PROJ.GUID %}}}.{{%= CFG.NAME %}}|{{%= PLATFORM %}}.ActiveCfg = {{%= CFG.NAME %}}|{{%= PLATFORM %}}
		{{{%= PROJ.GUID %}}}.{{%= CFG.NAME %}}|{{%= PLATFORM %}}.Build.0 = {{%= CFG.NAME %}}|{{%= PLATFORM %}}
	{{% end %}}
	{{% end %}}
	EndGlobalSection
	GlobalSection(SolutionProperties) = preSolution
		HideSolutionNode = FALSE
	EndGlobalSection
	GlobalSection(NestedProjects) = preSolution
	{{% for _, PROJ in pairs(ALL_PROJS or {}) do %}}
		{{{%= PROJ.GUID %}}} = {{{%= GUID_NEW("@g" .. PROJ.GROUP) %}}}
	{{% end %}}
	{{% for _, GROUP in pairs(GROUPS or {}) do %}}
		{{% if GROUP.NAME ~= IGNORE_GROUP then %}}
		{{{%= GUID_NEW("@g" .. GROUP.NAME) %}}} = {{{%= ALL_GUID %}}}
		{{% end %}}
	{{% end %}}
	EndGlobalSection
	GlobalSection(ExtensibilityGlobals) = postSolution
		SolutionGuid = {63D02246-6BAD-4132-9325-6DDF29305452}
	EndGlobalSection
EndGlobal
