@echo off

set JS=../server/center/page/gm.js
set CSS=../server/center/page/gm.css
set TPL=../server/center/page/gm.html
set OUT=../server/center/gm_page.lua
set SCRIPT=../extend/lmake/ltemplate.lua

..\bin\lua.exe %SCRIPT% %TPL% %OUT% GM_CSS %CSS% GM_SCRIPT %JS%

pause

