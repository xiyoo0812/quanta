<?xml version="1.0" encoding="utf-8"?>
{{%
  local ALIBS = {}
  local STDAFX = nil
  local AINCLUDES = {}
  local ALIBDIRS = {}
  local ADEFINES = {}
  --依赖库名：LIBS写库名(自动补.lib)，WINDOWS_LIBS写完整文件名
  for _, CLIB in ipairs(LIBS or {}) do
    table.insert(ALIBS, CLIB .. ".lib")
  end
  for _, WLIB in ipairs(WINDOWS_LIBS or {}) do
    table.insert(ALIBS, WLIB)
  end
  --静态库依赖路径按配置目录(develop/release)拼接
  local function fmt_lib_paths(cfg_dir)
    local paths = {}
    for _, CLIB in ipairs(LIBS or {}) do
      table.insert(paths, string.format("$(SolutionDir)%s/%s/lib%s.lib", DST_LIB_DIR, cfg_dir, CLIB))
    end
    for _, WLIB in ipairs(WINDOWS_LIBS or {}) do
      table.insert(paths, string.format("$(SolutionDir)%s/%s/%s", DST_LIB_DIR, cfg_dir, WLIB))
    end
    return XML_ESCAPE(table.concat(paths, ";"))
  end
  for _, DDEF in pairs(DEFINES or {}) do
    table.insert(ADEFINES, DDEF)
  end
  for _, DDEF in pairs(WINDOWS_DEFINES or {}) do
    table.insert(ADEFINES, DDEF)
  end
  for _, WINC in pairs(WINDOWS_INCLUDES or {}) do
    local C_INC = string.gsub(WINC, '/', '\\')
    table.insert(AINCLUDES, C_INC)
  end
  for _, WLDIR in pairs(WINDOWS_LIBRARY_DIR or {}) do
    local FWLDIR = string.gsub(WLDIR, '/', '\\')
    table.insert(ALIBDIRS, FWLDIR)
  end
  for _, INC in pairs(INCLUDES or {}) do
    local C_INC = string.gsub(INC, '/', '\\')
    table.insert(AINCLUDES, C_INC)
  end
  for _, LIB_DIR in pairs(LIBRARY_DIR or {}) do
    local C_LIB_DIR = string.gsub(LIB_DIR, '/', '\\')
    table.insert(ALIBDIRS, C_LIB_DIR)
  end
  local FMT_LIBS = XML_ESCAPE(table.concat(ALIBS, ";"))
  local FMT_INCLUDES = XML_ESCAPE(table.concat(AINCLUDES, ";"))
  local FMT_LIBRARY_DIR = XML_ESCAPE(table.concat(ALIBDIRS, ";"))
  local FMT_DEFINES = XML_ESCAPE(table.concat(ADEFINES or {}, ";"))
  local ESC_PROJECT_NAME = XML_ESCAPE(PROJECT_NAME)
  local ESC_TARGET_NAME = XML_ESCAPE(TARGET_NAME)
  --编译配置统一定义在 share.lua 的 SOLUTION_CONFIGS，vcxproj/sln/slnx 共用
  local CONFIGS = SOLUTION_CONFIGS
  --工程类型 → MSBuild的ConfigurationType
  local CONFIG_TYPES = {
    exe = "Application",
    static = "StaticLibrary",
    dynamic = "DynamicLibrary",
  }
  local CONFIG_TYPE = CONFIG_TYPES[PROJECT_TYPE] or "Application"
  local ARGS = {RECURSION = RECURSION, OBJS = OBJS, EXCLUDE_FILE = EXCLUDE_FILE }
  local CINCLUDES, CSOURCES = COLLECT_SOURCES(WORK_DIR, SRC_DIRS, ARGS)
%}}
<Project DefaultTargets="Build" ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
  {{% for _, CFG in ipairs(CONFIGS) do %}}
    <ProjectConfiguration Include="{{%= CFG.NAME %}}|{{%= PLATFORM %}}">
      <Configuration>{{%= CFG.NAME %}}</Configuration>
      <Platform>{{%= PLATFORM %}}</Platform>
    </ProjectConfiguration>
  {{% end %}}
  </ItemGroup>
  <ItemGroup>
  {{% for _, CINC in pairs(CINCLUDES or {}) do %}}
    <ClInclude Include="{{%= XML_ESCAPE(CINC[1]) %}}" />
  {{% end %}}
  </ItemGroup>
  <ItemGroup>
  {{% for _, CSRC in pairs(CSOURCES or {}) do %}}
  {{% if string.match(CSRC[1], "stdafx.cpp") then %}}
    {{% STDAFX = true %}}
    <ClCompile Include="{{%= XML_ESCAPE(CSRC[1]) %}}">
      {{% for _, CFG in ipairs(CONFIGS) do %}}
      <PrecompiledHeader Condition="'$(Configuration)|$(Platform)'=='{{%= CFG.NAME %}}|{{%= PLATFORM %}}'">Create</PrecompiledHeader>
      {{% end %}}
    </ClCompile>
  {{% else %}}
    <ClCompile Include="{{%= XML_ESCAPE(CSRC[1]) %}}" />
  {{% end %}}
  {{% end %}}
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{{{%= GUID_NEW(PROJECT_NAME) %}}}</ProjectGuid>
    <RootNamespace>{{%= ESC_PROJECT_NAME %}}</RootNamespace>
    <Keyword>Win32Proj</Keyword>
    <WindowsTargetPlatformVersion>10.0</WindowsTargetPlatformVersion>
    <ProjectName>{{%= ESC_PROJECT_NAME %}}</ProjectName>
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
  {{% for _, CFG in ipairs(CONFIGS) do %}}
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='{{%= CFG.NAME %}}|{{%= PLATFORM %}}'" Label="Configuration">
    <ConfigurationType>{{%= CONFIG_TYPE %}}</ConfigurationType>
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <PlatformToolset>v{{%= MSVC_TOOLSET %}}</PlatformToolset>
    <CharacterSet>MultiByte</CharacterSet>
  </PropertyGroup>
  {{% end %}}
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
  </ImportGroup>
  {{% for _, CFG in ipairs(CONFIGS) do %}}
  <ImportGroup Condition="'$(Configuration)|$(Platform)'=='{{%= CFG.NAME %}}|{{%= PLATFORM %}}'" Label="PropertySheets">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  {{% end %}}
  <PropertyGroup Label="UserMacros" />
  <PropertyGroup>
    <_ProjectFileVersion>11.0.50727.1</_ProjectFileVersion>
  </PropertyGroup>
  {{% for _, CFG in ipairs(CONFIGS) do %}}
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='{{%= CFG.NAME %}}|{{%= PLATFORM %}}'">
    <TargetName>{{%= ESC_TARGET_NAME %}}</TargetName>
    <OutDir>$(SolutionDir)temp\bin\$(Platform)\{{%= CFG.DIR %}}\</OutDir>
    <IntDir>$(SolutionDir)temp\$(ProjectName)\$(Platform)\{{%= CFG.DIR %}}\</IntDir>
  </PropertyGroup>
  {{% end %}}
  {{%
  for _, CFG in ipairs(CONFIGS) do
    local CFG_LIB_DIR = string.format("$(SolutionDir)%s\\%s", DST_LIB_DIR, CFG.DIR)
    local CFG_BIN_DIR = string.format("$(SolutionDir)%s\\%s", DST_DIR, CFG.DIR)
    local FMT_ASAS = fmt_lib_paths(CFG.DIR)
  %}}
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='{{%= CFG.NAME %}}|{{%= PLATFORM %}}'">
    <ClCompile>
      <Optimization>{{%= CFG.OPTIMIZATION %}}</Optimization>
      <AdditionalIncludeDirectories>{{%= FMT_INCLUDES %}};%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>WIN32;NDEBUG;_WINDOWS;_CRT_SECURE_NO_WARNINGS;{{%= FMT_DEFINES %}};%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <BasicRuntimeChecks>Default</BasicRuntimeChecks>
      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
      {{% if STDAFX then %}}
      <PrecompiledHeader>Use</PrecompiledHeader>
      {{% else %}}
      <PrecompiledHeader></PrecompiledHeader>
      {{% end %}}
      <WarningLevel>Level3</WarningLevel>
      <CompileAs>Default</CompileAs>
      {{% if STDCPP == "c++17" then %}}
      <LanguageStandard>stdcpp17</LanguageStandard>
      {{% end %}}
      {{% if STDCPP == "c++20" then %}}
      <LanguageStandard>stdcpp20</LanguageStandard>
      {{% end %}}
      {{% if STDCPP == "c++23" then %}}
      <LanguageStandard>stdcpp23</LanguageStandard>
      {{% end %}}
      <ConformanceMode>true</ConformanceMode>
      <AdditionalOptions>/utf-8 %(AdditionalOptions)</AdditionalOptions>
    </ClCompile>
    {{% if PROJECT_TYPE == "static" then %}}
	  <Lib>
      <LibAdditionalDependencies>{{%= FMT_ASAS %}};%(LibAdditionalDependencies)</LibAdditionalDependencies>
    </Lib>
    {{% else %}}
    <Link>
      <OutputFile>$(OutDir)$(TargetName)$(TargetExt)</OutputFile>
      <AdditionalLibraryDirectories>{{%= CFG_LIB_DIR %}};{{%= FMT_LIBRARY_DIR %}};%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>
      <GenerateDebugInformation>{{%= CFG.DEBUG_INFO and "true" or "false" %}}</GenerateDebugInformation>
      <SubSystem>Console</SubSystem>
      <ImportLibrary>{{%= CFG_LIB_DIR %}}\$(TargetName).lib</ImportLibrary>
      <ProgramDatabaseFile>$(IntDir)$(TargetName).pdb</ProgramDatabaseFile>
      <AdditionalDependencies>{{%= FMT_LIBS %}};%(AdditionalDependencies)</AdditionalDependencies>
      <ForceFileOutput>
      </ForceFileOutput>
    </Link>
    {{% end %}}
    <PreBuildEvent>
      {{%
        --VS 不会自动创建 library/bin 的配置目录（临时目录由 VS 自动创建）
        local pre_commands = {
          string.format('if not exist "%s" mkdir "%s"', CFG_LIB_DIR, CFG_LIB_DIR),
          string.format('if not exist "%s" mkdir "%s"', CFG_BIN_DIR, CFG_BIN_DIR),
        }
        for _, PREBUILD_CMD in pairs(WINDOWS_PREBUILDS) do
          local pre_build_cmd = string.gsub(PREBUILD_CMD[2], '/', '\\')
          table.insert(pre_commands, string.format("%s %s", PREBUILD_CMD[1], pre_build_cmd))
        end
      %}}
      {{%= string.format("<Command>%s</Command>", XML_ESCAPE(table.concat(pre_commands, "\n"))) %}}
    </PreBuildEvent>
    <PostBuildEvent>
      {{%
        local post_commands = {}
        if PROJECT_TYPE == "static" then
          table.insert(post_commands, string.format('copy /y $(TargetPath) "%s"', CFG_LIB_DIR))
        else
          table.insert(post_commands, string.format('copy /y $(TargetPath) "%s"', CFG_BIN_DIR))
        end
        for _, POSTBUILD_CMD in pairs(WINDOWS_POSTBUILDS) do
          local post_build_cmd = string.gsub(POSTBUILD_CMD[2], '/', '\\')
          table.insert(post_commands, string.format("%s %s", POSTBUILD_CMD[1], post_build_cmd))
        end
      %}}
      {{%= string.format("<Command>%s</Command>", XML_ESCAPE(table.concat(post_commands, "\n"))) %}}
    </PostBuildEvent>
  </ItemDefinitionGroup>
  {{% end %}}
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />
  <ImportGroup Label="ExtensionTargets">
  </ImportGroup>
</Project>