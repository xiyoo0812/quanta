<?xml version="1.0" encoding="utf-8"?>
{{% local ALIBS = {} %}}
{{% local STDAFX = nil %}}
{{% local AINCLUDES = {} %}}
{{% local ALIBDIRS = {} %}}
{{% local ADEFINES = {} %}}
{{% for _, CLIB in pairs(LIBS or {}) do %}}
{{% table.insert(ALIBS, CLIB .. ".lib") %}}
{{% end %}}
{{% for _, WLIB in pairs(WINDOWS_LIBS or {}) do %}}
{{% table.insert(ALIBS, WLIB) %}}
{{% end %}}
{{% for _, DDEF in pairs(DEFINES or {}) do %}}
{{% table.insert(ADEFINES, DDEF) %}}
{{% end %}}
{{% for _, DDEF in pairs(WINDOWS_DEFINES or {}) do %}}
{{% table.insert(ADEFINES, DDEF) %}}
{{% end %}}
{{% for _, WINC in pairs(WINDOWS_INCLUDES or {}) do %}}
{{% local C_INC = string.gsub(WINC, '/', '\\') %}}
{{% table.insert(AINCLUDES, C_INC) %}}
{{% end %}}
{{% for _, WLDIR in pairs(WINDOWS_LIBRARY_DIR or {}) do %}}
{{% local FWLDIR = string.gsub(WLDIR, '/', '\\') %}}
{{% table.insert(ALIBDIRS, FWLDIR) %}}
{{% end %}}
{{% for _, INC in pairs(INCLUDES or {}) do %}}
{{% local C_INC = string.gsub(INC, '/', '\\') %}}
{{% table.insert(AINCLUDES, C_INC) %}}
{{% end %}}
{{% if MIMALLOC and MIMALLOC_DIR then %}}
{{% table.insert(ALIBS, "mimalloc.lib") %}}
{{% local FMIMALLOC_DIR = string.gsub(MIMALLOC_DIR, '/', '\\') %}}
{{% table.insert(AINCLUDES, "$(SolutionDir)" .. FMIMALLOC_DIR) %}}
{{% end %}}
{{% for _, LIB_DIR in pairs(LIBRARY_DIR or {}) do %}}
{{% local C_LIB_DIR = string.gsub(LIB_DIR, '/', '\\') %}}
{{% table.insert(ALIBDIRS, C_LIB_DIR) %}}
{{% end %}}
{{% local FMT_LIBS = table.concat(ALIBS, ";") %}}
{{% local FMT_INCLUDES = table.concat(AINCLUDES, ";") %}}
{{% local FMT_LIBRARY_DIR = table.concat(ALIBDIRS, ";") %}}
{{% local FMT_DEFINES = table.concat(ADEFINES or {}, ";") %}}
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
  {{% if string.match(CSRC[1], "stdafx.cpp") then %}}
    {{% STDAFX = true %}}
    <ClCompile Include="{{%= CSRC[1] %}}">
      <PrecompiledHeader Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'">Create</PrecompiledHeader>
      <PrecompiledHeader Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'">Create</PrecompiledHeader>
    </ClCompile>
  {{% else %}}
    <ClCompile Include="{{%= CSRC[1] %}}" />
  {{% end %}}
  {{% end %}}
  </ItemGroup>
  <PropertyGroup Label="Globals">
    <ProjectName>{{%= PROJECT_NAME %}}</ProjectName>
    <ProjectGuid>{{{%= GUID_NEW(PROJECT_NAME) %}}}</ProjectGuid>
    <RootNamespace>{{%= PROJECT_NAME %}}</RootNamespace>
    <Keyword>Win32Proj</Keyword>
    <MinimumVisualStudioVersion>15.0</MinimumVisualStudioVersion>
    <TargetRuntime>Native</TargetRuntime>
    <PreferredToolArchitecture>x64</PreferredToolArchitecture>
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
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <PlatformToolset>v{{%= MSVC_TOOLSET %}}</PlatformToolset>
    <CharacterSet>Unicode</CharacterSet>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'" Label="Configuration">
    {{% if PROJECT_TYPE == "dynamic" then %}}
    <ConfigurationType>DynamicLibrary</ConfigurationType>
    {{% elseif PROJECT_TYPE == "static" then %}}
    <ConfigurationType>StaticLibrary</ConfigurationType>
    {{% else %}}
    <ConfigurationType>Application</ConfigurationType>
    {{% end %}}
    <WholeProgramOptimization>true</WholeProgramOptimization>
    <PlatformToolset>v{{%= MSVC_TOOLSET %}}</PlatformToolset>
    <CharacterSet>Unicode</CharacterSet>
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
  <PropertyGroup>
    <_ProjectFileVersion>11.0.50727.1</_ProjectFileVersion>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'">
    <TargetName>{{%= TARGET_NAME %}}</TargetName>
    <OutDir>$(SolutionDir)temp\bin\$(Platform)\</OutDir>
    <IntDir>$(SolutionDir)temp\$(ProjectName)\$(Platform)\</IntDir>
    <ReferencePath>$(Console_SdkLibPath);$(Console_SdkWindowsMetadataPath)</ReferencePath>
    <LibraryPath>$(Console_SdkLibPath)</LibraryPath>
    <LibraryWPath>$(Console_SdkLibPath);$(Console_SdkWindowsMetadataPath)</LibraryWPath>
    <IncludePath>$(Console_SdkIncludeRoot)</IncludePath>
    <ExecutablePath>$(Console_SdkRoot)bin;$(Console_SdkToolPath);$(ExecutablePath)</ExecutablePath>
  </PropertyGroup>
  <PropertyGroup Condition="'$(Configuration)|$(Platform)'=='Release|{{%= PLATFORM %}}'">
    <TargetName>{{%= TARGET_NAME %}}</TargetName>
    <OutDir>$(SolutionDir)temp\bin\$(Platform)\</OutDir>
    <IntDir>$(SolutionDir)temp\$(ProjectName)\$(Platform)\</IntDir>
    <ReferencePath>$(Console_SdkLibPath);$(Console_SdkWindowsMetadataPath)</ReferencePath>
    <LibraryPath>$(Console_SdkLibPath)</LibraryPath>
    <LibraryWPath>$(Console_SdkLibPath);$(Console_SdkWindowsMetadataPath)</LibraryWPath>
    <IncludePath>$(Console_SdkIncludeRoot)</IncludePath>
    <ExecutablePath>$(Console_SdkRoot)bin;$(Console_SdkToolPath);$(ExecutablePath)</ExecutablePath>
  </PropertyGroup>
  <ItemDefinitionGroup Condition="'$(Configuration)|$(Platform)'=='Debug|{{%= PLATFORM %}}'">
    <ClCompile>
      <Optimization>{{%= OPTIMIZE and "MaxSpeed" or "Disabled" %}}</Optimization>
      <AdditionalIncludeDirectories>{{%= FMT_INCLUDES %}};%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>_DEBUG;_CRT_SECURE_NO_WARNINGS;{{%= FMT_DEFINES %}};%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <BasicRuntimeChecks>Default</BasicRuntimeChecks>
      <RuntimeLibrary>MultiThreadedDebugDLL</RuntimeLibrary>
      {{% if STDAFX then %}}
      <PrecompiledHeader>Use</PrecompiledHeader>
      {{% else %}}
      <PrecompiledHeader></PrecompiledHeader>
      {{% end %}}
      <WarningLevel>Level4</WarningLevel>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <CompileAs>Default</CompileAs>
      {{% if MIMALLOC and MIMALLOC_DIR then %}}
      <ForcedIncludeFiles>..\..\mimalloc-ex.h</ForcedIncludeFiles>
      {{% end %}}
      {{% if STDCPP == "c++17" then %}}
      <LanguageStandard>stdcpp17</LanguageStandard>
      {{% end %}}
      {{% if STDCPP == "c++20" then %}}
      <LanguageStandard>stdcpp20</LanguageStandard>
      {{% end %}}
      <ConformanceMode>true</ConformanceMode>
      <AdditionalOptions>/Zc:__cplusplus %(AdditionalOptions)</AdditionalOptions>
    </ClCompile>
    {{% if PROJECT_TYPE ~= "static" then %}}
    <Link>
      <OutputFile>$(OutDir)$(TargetName)$(TargetExt)</OutputFile>
      <AdditionalLibraryDirectories>$(SolutionDir){{%= DST_LIB_DIR %}}\$(Platform);{{%= FMT_LIBRARY_DIR %}};%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <SubSystem>Windows</SubSystem>
      <ImportLibrary>$(SolutionDir){{%= DST_LIB_DIR %}}\$(Platform)\$(TargetName).lib</ImportLibrary>
      <ProgramDatabaseFile>$(SolutionDir)temp\$(ProjectName)\$(Platform)\$(TargetName).pdb</ProgramDatabaseFile>
      <AdditionalDependencies>$(Console_Libs);%(XboxExtensionsDependencies);{{%= FMT_LIBS %}};%(AdditionalDependencies)</AdditionalDependencies>
      <ForceFileOutput>
      </ForceFileOutput>
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
      <Optimization>{{%= OPTIMIZE and "MaxSpeed" or "Disabled" %}}</Optimization>
      <AdditionalIncludeDirectories>{{%= FMT_INCLUDES %}};%(AdditionalIncludeDirectories)</AdditionalIncludeDirectories>
      <PreprocessorDefinitions>NDEBUG;_CRT_SECURE_NO_WARNINGS;{{%= FMT_DEFINES %}};%(PreprocessorDefinitions)</PreprocessorDefinitions>
      <BasicRuntimeChecks>Default</BasicRuntimeChecks>
      <RuntimeLibrary>MultiThreadedDLL</RuntimeLibrary>
      {{% if STDAFX then %}}
      <PrecompiledHeader>Use</PrecompiledHeader>
      {{% else %}}
      <PrecompiledHeader></PrecompiledHeader>
      {{% end %}}
      <WarningLevel>Level4</WarningLevel>
      <FunctionLevelLinking>true</FunctionLevelLinking>
      <IntrinsicFunctions>true</IntrinsicFunctions>
      <CompileAs>Default</CompileAs>
      {{% if MIMALLOC and MIMALLOC_DIR then %}}
      <ForcedIncludeFiles>..\..\mimalloc-ex.h</ForcedIncludeFiles>
      {{% end %}}
      {{% if STDCPP == "c++17" then %}}
      <LanguageStandard>stdcpp17</LanguageStandard>
      {{% end %}}
      {{% if STDCPP == "c++20" then %}}
      <LanguageStandard>stdcpp20</LanguageStandard>
      {{% end %}}
      <ConformanceMode>true</ConformanceMode>
      <AdditionalOptions>/Zc:__cplusplus %(AdditionalOptions)</AdditionalOptions>
    </ClCompile>
    {{% if PROJECT_TYPE ~= "static" then %}}
    <Link>
      <OutputFile>$(OutDir)$(TargetName)$(TargetExt)</OutputFile>
      <AdditionalLibraryDirectories>$(SolutionDir){{%= DST_LIB_DIR %}}\$(Platform);{{%= FMT_LIBRARY_DIR %}};%(AdditionalLibraryDirectories)</AdditionalLibraryDirectories>
      <GenerateDebugInformation>true</GenerateDebugInformation>
      <SubSystem>Windows</SubSystem>
      <ImportLibrary>$(SolutionDir){{%= DST_LIB_DIR %}}\$(Platform)\$(TargetName).lib</ImportLibrary>
      <ProgramDatabaseFile>$(SolutionDir)temp\$(ProjectName)\$(Platform)\$(TargetName).pdb</ProgramDatabaseFile>
      <AdditionalDependencies>$(Console_Libs);%(XboxExtensionsDependencies);{{%= FMT_LIBS %}};%(AdditionalDependencies)</AdditionalDependencies>
      <ForceFileOutput>
      </ForceFileOutput>
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