@echo off
set DATA_UTILS_JS=../server/robot/accord/page/data_utils.js
set FORMAT_UTILS_JS=../server/robot/accord/page/format_utils.js
set NET_UTILS_JS=../server/robot/accord/page/net_utils.js
set STYLE_CSS=../server/robot/accord/page/style.css
set TPL=../server/robot/accord/page/index.html
set OUT=../server/robot/accord/index.lua
set SCRIPT=../extend/lmake/ltemplate.lua

..\bin\lua.exe %SCRIPT% %TPL% %OUT% DATA_UTILS_JS %DATA_UTILS_JS% FORMAT_UTILS_JS %FORMAT_UTILS_JS% NET_UTILS_JS %NET_UTILS_JS% STYLE_CSS %STYLE_CSS%

pause

