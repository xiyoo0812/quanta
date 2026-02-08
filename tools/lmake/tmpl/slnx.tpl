<Solution>
  <Configurations>
    <Platform Name="x64"/>
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
  <Folder Name="/all/{{%= GROUP.NAME %}}/">
     {{% for _, PROJECT in ipairs(GROUP.PROJECTS or {}) do %}}
     {{% local PROJECT_DIR = string.gsub(PROJECT.DIR, '/', '\\') %}}
     {{% if #PROJECT.DEPS > 0 then %}}
     <Project Path="{{%= PROJECT_DIR %}}\{{%= PROJECT.FILE %}}.vcxproj" Id="{{%= PROJECT.GUID %}}">
        {{% for _, DEP in ipairs(PROJECT.DEPS) do %}}
        {{% local PROJ = ALL_PROJS[DEP] %}}
        {{% if PROJ.NAME == DEP then %}}
        {{% local PROJ_DIR = string.gsub(PROJ.DIR, '/', '\\') %}}
        <BuildDependency Project="{{%= PROJ_DIR %}}\{{%= PROJ.FILE %}}.vcxproj"/>
        {{% end %}}
        {{% end %}}
     </Project>
     {{% else %}}
     <Project Path="{{%= PROJECT_DIR %}}\{{%= PROJECT.FILE %}}.vcxproj" Id="{{%= PROJECT.GUID %}}"/>
     {{% end %}}
     {{% end %}}
  </Folder>
  {{% end %}}
  {{% end %}}
</Solution>