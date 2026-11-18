{{% local CONFIGS = SOLUTION_CONFIGS %}}
<Solution>
  <Configurations>
  {{% for _, CFG in ipairs(CONFIGS) do %}}
    <BuildType Name="{{%= XML_ESCAPE(CFG.NAME) %}}" />
  {{% end %}}
    <Platform Name="{{%= XML_ESCAPE(PLATFORM) %}}" />
  </Configurations>
  {{%
    local ALL_PROJS = {}
    for _, GROUP in pairs(GROUPS or {}) do
      for _, PROJ in ipairs(GROUP.PROJECTS) do
        ALL_PROJS[PROJ.NAME] = PROJ
      end
    end
  %}}
  {{% for _, GROUP in pairs(GROUPS or {}) do %}}
  {{% if GROUP.NAME ~= IGNORE_GROUP then %}}
  <Folder Name="/all/{{%= XML_ESCAPE(GROUP.NAME) %}}/">
     {{% for _, PROJECT in ipairs(GROUP.PROJECTS or {}) do %}}
     {{% local PROJECT_DIR = XML_ESCAPE(string.gsub(PROJECT.DIR, '/', '\\')) %}}
     {{% if #PROJECT.DEPS > 0 then %}}
     <Project Path="{{%= PROJECT_DIR %}}\{{%= XML_ESCAPE(PROJECT.FILE) %}}.vcxproj" Id="{{%= PROJECT.GUID %}}">
        {{% for _, DEP in ipairs(PROJECT.DEPS) do %}}
        {{% local PROJ = ALL_PROJS[DEP] %}}
        {{% if PROJ.NAME == DEP then %}}
        {{% local PROJ_DIR = XML_ESCAPE(string.gsub(PROJ.DIR, '/', '\\')) %}}
        <BuildDependency Project="{{%= PROJ_DIR %}}\{{%= XML_ESCAPE(PROJ.FILE) %}}.vcxproj" />
        {{% end %}}
        {{% end %}}
     </Project>
     {{% else %}}
     <Project Path="{{%= PROJECT_DIR %}}\{{%= XML_ESCAPE(PROJECT.FILE) %}}.vcxproj" Id="{{%= PROJECT.GUID %}}" />
     {{% end %}}
     {{% end %}}
  </Folder>
  {{% end %}}
  {{% end %}}
</Solution>