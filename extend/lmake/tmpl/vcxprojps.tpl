<?xml version="1.0" encoding="utf-8"?>
{{% local AINCLUDES = {} %}}
{{% local ALIBDIRS = {} %}}
{{% local FMT_LIBS = "" %}}
{{% local ADEFINES = {} %}}
{{% local PROJECT_PREFIX = "" %}}
{{% if LIB_PREFIX then %}}
{{% PROJECT_PREFIX = "lib" %}}
{{% end %}}
{{% for _, CLIB in pairs(LIBS or {}) do %}}
{{% FMT_LIBS = string.format("%s-l%s;", FMT_LIBS, CLIB) %}}
{{% end %}}
{{% for _, PSLIB in pairs(PSLIBS or {}) do %}}
{{% FMT_LIBS = string.format("%s-l%s;", FMT_LIBS, PSLIB) %}}
{{% end %}}
{{% for _, DDEF in pairs(DEFINES or {}) do %}}
{{% table.insert(ADEFINES, DDEF) %}}
{{% end %}}
{{% for _, DDEF in pairs(PS_DEFINES or {}) do %}}
{{% table.insert(ADEFINES, DDEF) %}}
{{% end %}}
{{% local FMT_DEFINES = table.concat(ADEFINES or {}, ";") %}}
{{% for _, INC in pairs(INCLUDES or {}) do %}}
{{% local C_INC = string.gsub(INC, '/', '\\') %}}
{{% table.insert(AINCLUDES, C_INC) %}}
{{% end %}}
{{% for _, LIB_DIR in pairs(LIBRARY_DIR or {}) do %}}
{{% local C_LIB_DIR = string.gsub(LIB_DIR, '/', '\\') %}}
{{% table.insert(ALIBDIRS, C_LIB_DIR) %}}
{{% end %}}
{{% local FMT_INCLUDES = table.concat(AINCLUDES, ";") %}}
{{% local FMT_LIBRARY_DIR = table.concat(ALIBDIRS, ";") %}}
{{% local ARGS = {RECURSION = RECURSION, OBJS = OBJS, EXCLUDE_FILE = EXCLUDE_FILE } %}}
{{% local CINCLUDES, CSOURCES = COLLECT_SOURCES(WORK_DIR, SRC_DIRS, ARGS) %}}
<Project DefaultTargets="Build" ToolsVersion="15.0" xmlns="http://schemas.microsoft.com/developer/msbuild/2003">
  <ItemGroup Label="ProjectConfigurations">
    <ProjectConfiguration Include="Debug|{{%= PLATFORM %}}">
      <Configuration>Debug</Configuration>
      <Platform>{{%= PLATFORM %}}</Platform>
    </ProjectConfiguration>
    <ProjectConfiguration Include="Release|{{%= PLATFORM %}}">
      <Configuration>Release</Configuration>
      <Platform>{{%= PLATFORM %}}</Platform>
    </ProjectConfiguration>
  </ItemGroup>
  <ItemGroup>
  {{% for _, CINC in pairs(CINCLUDES or {}) do %}}
    <ClInclude Include="{{%= CINC[1] %}}" />
  {{% end %}}
  </ItemGroup>
  <ItemGroup>
  {{% for _, CSRC in pairs(CSOURCES or {}) do %}}
    <ClCompile Include="{{%= CSRC[1] %}}" />
  {{% end %}}
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectGuid>{{{%= GUID_NEW(PROJECT_NAME) %}}}</ProjectGuid>
    <ProjectName>{{%= PROJECT_NAME %}}</ProjectName>
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.Default.props" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'" Label="Configuration">
    {{% if PROJECT_TYPE == "dynamic" then %}}
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    {{% elseif PROJECT_TYPE == "static" then %}}
    <ConfigurationType>StaticLibrary</ConfigurationType>
    {{% else %}}
    <ConfigurationType>Application</ConfigurationType>
    {{% end %}}
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'" Label="Configuration">
    {{% if PROJECT_TYPE == "dynamic" then %}}
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    {{% elseif PROJECT_TYPE == "static" then %}}
    <ConfigurationType>StaticLibrary</ConfigurationType>
    {{% else %}}
    <ConfigurationType>Application</ConfigurationType>
    {{% end %}}
  </PropertyGroup>
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.props" />
  <ImportGroup Label="ExtensionSettings">
  </ImportGroup>
  <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'" Label="PropertySheets">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <ImportGroup Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'" Label="PropertySheets">
    <Import Project="$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props" Condition="exists('$(UserRootDir)\Microsoft.Cpp.$(Platform).user.props')" Label="LocalAppDataPlatform" />
  </ImportGroup>
  <PropertyGroup Label="UserMacros" />
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'">
    <TargetName>{{%= PROJECT_PREFIX %}}{{%= TARGET_NAME %}}</TargetName>
    <OutDir>$(SolutionDir)temp\bin\$(Platform)\</OutDir>
    <IntDir>$(SolutionDir)temp\$(ProjectName)\$(Platform)\</IntDir>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'">
    <TargetName>{{%= PROJECT_PREFIX %}}{{%= TARGET_NAME %}}</TargetName>
    <OutDir>$(SolutionDir)temp\bin\$(Platform)\</OutDir>
    <IntDir>$(SolutionDir)temp\$(ProjectName)\$(Platform)\</IntDir>
  </PropertyGroup>
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'">
    <ClCompile>
      {{% if STDCPP == "c++17" then %}}
      <CppLanguageStd>Cpp17</CppLanguageStd>
      {{% end %}}
      {{% if STDCPP == "c++14" then %}}
      <CppLanguageStd>Cpp14</CppLanguageStd>
      {{% end %}}
      <CppExceptions>true</CppExceptions>
      <RuntimeTypeInfo>true</RuntimeTypeInfo>
      {{% if FORCE_INCLUDE then %}}
      <ForcedIncludeFiles>{{%= FORCE_INCLUDE %}}</ForcedIncludeFiles>
      {{% end %}}
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <OptimizationLevel>{{%= OPTIMIZE and "Level2" or "Level0" %}}</OptimizationLevel>
      <PreprocessorDefinitions>_DEBUG;{{%= FMT_DEFINES %}};%(PreprocessorDefinitions);</PreprocessorDefinitions>
      <AdditionalIncludeDirectories>{{%= FMT_INCLUDES %}};%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>     
    </ClCompile>
    {{% if PROJECT_TYPE ~= "static" then %}}
    <Link>
      <OutputFile>$(OutDir)$(TargetName)$(TargetExt)</OutputFile>
      <AdditionalLibraryDirectories>$(SolutionDir){{%= DST_DIR %}};$(SolutionDir){{%= DST_LIB_DIR %}}\$(Platform);{{%= FMT_LIBRARY_DIR %}};%(AdditionalLibraryDirectories)
      </AdditionalLibraryDirectories>
      <ImportLibrary></ImportLibrary>
      <AdditionalDependencies>{{%= FMT_LIBS %}};%(AdditionalDependencies)</AdditionalDependencies>
      <AdditionalOptions>%(AdditionalOptions)</AdditionalOptions>
    </Link>
    {{% end %}}
    <PreBuildEvent>
      {{% if next(WINDOWS_PREBUILDS) then %}}
      {{% local pre_commands = {} %}}
      {{% for _, PREBUILD_CMD in pairs(WINDOWS_PREBUILDS) do %}}
      {{% local pre_build_cmd = string.gsub(PREBUILD_CMD[2], '/', '\\') %}}
      {{% table.insert(pre_commands, string.format("%s %s", PREBUILD_CMD[1], pre_build_cmd)) %}}
      {{% end %}}
      {{%= string.format("<Command>%s</Command>", table.concat(pre_commands, "\n")) %}}
      {{% end %}}
    </PreBuildEvent>
    <PostBuildEvent>
      {{% local post_commands = {} %}}
      {{% if PROJECT_TYPE == "static" then %}}
      {{% local dst_lib_dir = string.format("$(SolutionDir)%s/$(Platform)", DST_LIB_DIR) %}}
      {{% local dst_dir = string.gsub(dst_lib_dir, '/', '\\') %}}
      {{% table.insert(post_commands, string.format("copy /y $(TargetPath) %s", dst_dir)) %}}
      {{% else %}}
      {{% local dst_dir = string.gsub(DST_DIR, '/', '\\') %}}
      {{% table.insert(post_commands, string.format("copy /y $(TargetPath) $(SolutionDir)%s", dst_dir)) %}}
      {{% end %}}
      {{% for _, POSTBUILD_CMD in pairs(WINDOWS_POSTBUILDS) do %}}
      {{% local post_build_cmd = string.gsub(POSTBUILD_CMD[2], '/', '\\') %}}
      {{% table.insert(post_commands, string.format("%s %s", POSTBUILD_CMD[1], post_build_cmd)) %}}
      {{% end %}}
      {{%= string.format("<Command>%s</Command>", table.concat(post_commands, "\n")) %}}
    </PostBuildEvent>
  </ItemDefinitionGroup>
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'">
    <ClCompile>
      {{% if STDCPP == "c++17" then %}}
      <CppLanguageStd>Cpp17</CppLanguageStd>
      {{% end %}}
      {{% if STDCPP == "c++14" then %}}
      <CppLanguageStd>Cpp14</CppLanguageStd>
      {{% end %}}
      <CppExceptions>true</CppExceptions>
      <RuntimeTypeInfo>true</RuntimeTypeInfo>
      {{% if FORCE_INCLUDE then %}}
      <ForcedIncludeFiles>{{%= FORCE_INCLUDE %}}</ForcedIncludeFiles>
      {{% end %}}
      <GenerateDebugInformation>false</GenerateDebugInformation>
      <OptimizationLevel>{{%= OPTIMIZE and "Level2" or "Level0" %}}</OptimizationLevel>
      <PreprocessorDefinitions>NDEBUG;{{%= FMT_DEFINES %}};%(PreprocessorDefinitions);</PreprocessorDefinitions>
      <AdditionalIncludeDirectories>{{%= FMT_INCLUDES %}};%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>     
    </ClCompile>
    {{% if PROJECT_TYPE ~= "static" then %}}
    <Link>
      <OutputFile>$(OutDir)$(TargetName)$(TargetExt)</OutputFile>
      <AdditionalLibraryDirectories>$(SolutionDir){{%= DST_DIR %}};$(SolutionDir){{%= DST_LIB_DIR %}}\$(Platform);{{%= FMT_LIBRARY_DIR %}};%(AdditionalLibraryDirectories)
      </AdditionalLibraryDirectories>
      <ImportLibrary></ImportLibrary>
      <AdditionalDependencies>{{%= FMT_LIBS %}};%(AdditionalDependencies)</AdditionalDependencies>
      <AdditionalOptions>%(AdditionalOptions)</AdditionalOptions>
    </Link>
    {{% end %}}
    <PreBuildEvent>
      {{% if next(WINDOWS_PREBUILDS) then %}}
      {{% local pre_commands = {} %}}
      {{% for _, PREBUILD_CMD in pairs(WINDOWS_PREBUILDS) do %}}
      {{% local pre_build_cmd = string.gsub(PREBUILD_CMD[2], '/', '\\') %}}
      {{% table.insert(pre_commands, string.format("%s %s", PREBUILD_CMD[1], pre_build_cmd)) %}}
      {{% end %}}
      {{%= string.format("<Command>%s</Command>", table.concat(pre_commands, "\n")) %}}
      {{% end %}}
    </PreBuildEvent>
    <PostBuildEvent>
      {{% local post_commands = {} %}}
      {{% if PROJECT_TYPE == "static" then %}}
      {{% local dst_lib_dir = string.format("$(SolutionDir)%s/$(Platform)", DST_LIB_DIR) %}}
      {{% local dst_dir = string.gsub(dst_lib_dir, '/', '\\') %}}
      {{% table.insert(post_commands, string.format("copy /y $(TargetPath) %s", dst_dir)) %}}
      {{% else %}}
      {{% local dst_dir = string.gsub(DST_DIR, '/', '\\') %}}
      {{% table.insert(post_commands, string.format("copy /y $(TargetPath) $(SolutionDir)%s", dst_dir)) %}}
      {{% end %}}
      {{% for _, POSTBUILD_CMD in pairs(WINDOWS_POSTBUILDS) do %}}
      {{% local post_build_cmd = string.gsub(POSTBUILD_CMD[2], '/', '\\') %}}
      {{% table.insert(post_commands, string.format("%s %s", POSTBUILD_CMD[1], post_build_cmd)) %}}
      {{% end %}}
      {{%= string.format("<Command>%s</Command>", table.concat(post_commands, "\n")) %}}
    </PostBuildEvent>
  </ItemDefinitionGroup>
  <Import Project="$(VCTargetsPath)\Microsoft.Cpp.targets" />
  <ImportGroup Label="ExtensionTargets">
  </ImportGroup>
</Project>