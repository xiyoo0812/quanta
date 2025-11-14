<Solution>
  <Configurations>
    <Platform Name="x64" />
  </Configurations>
  {{% for _, GROUP in pairs(GROUPS or {}) do %}}
  {{% if GROUP.NAME ~= IGNORE_GROUP then %}}
  <Folder Name="/all/{{%= GROUP.NAME %}}/">
     {{% for _, PROJECT in ipairs(GROUP.PROJECTS or {}) do %}}
     {{% local PROJECT_DIR = string.gsub(PROJECT.DIR, '/', '\\') %}}
     <Project Path="{{%= PROJECT_DIR %}}/{{%= PROJECT.FILE %}}.vcxproj" Id="{{%= PROJECT.GUID %}}" />
     {{% end %}}
  </Folder>
  {{% end %}}
  {{% end %}}
</Solution>