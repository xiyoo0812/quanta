--xml_test.lua
--luacheck: ignore 631

require "luaxml"
local log_dump  = logger.dump

local cxml = [[
<XperiML version="2.0">
  <!--  application info -->
  <applicationInfo>
    <string id="author">     J&#228;ne.Roe@t&#252;bingen.com </string>
    <string id="version">    0.5.0                         </string>
    <string id="date">       2004-11-23 - 2006-08-18       </string>
    <string id="shortDescr"> a demonstration application for veLib Lua scripting </string>
    <string id="usage">      [ -i(ini.xml) ] </string>
    <tag id="emptyAttr" attr="" />
  </applicationInfo>

  <!--  initialization of the glWindow -->
  <deviceWindow id="0" name="window" deviceContainer="input">
    <string id="winTitle">   veLua </string>
    <float id="mouseRelative">     0 </float>
    <float id="mouseNeutral">    0.0 </float>
    <bool id="mouseVisible">       0 </bool>
    <bool id="fullScreen">         0 </bool>
    <int  id="zBufferBits">       24 </int>
    <int  id="stencilBufferBits">  0 </int>

    <int id="winSizeX">        800 </int>
    <int id="winSizeY">        600 </int>
    <floatArray id="bgColor"> 0.5 0.6 0.7 </floatArray>

    <!-- 2d viewport / overlay initialization -->
    <overlay>
      <floatArray id="bgNormalColor"> 1.0 1.0 1.0 0.2 </floatArray>
      <floatArray id="fgNormalColor"> 1.0 0.0 1.0 0.7 </floatArray>
      <floatArray id="bgSelectColor"> 0.0 0.5 1.0 0.7 </floatArray>
      <floatArray id="fgSelectColor"> 1.0 1.0 1.0 1.0 </floatArray>
      <!-- overlay plane minimum and maximum coordinates -->
      <float id="minX"> -1.0 </float>
      <float id="minY"> -1.0 </float>
      <float id="maxX">  1.0 </float>
      <float id="maxY">  1.0 </float>
    </overlay>

    <!--                 X   Y   Z   H   P   R (output axes) -->
    <axesInputMapping>   0   1   2   3   4   5 </axesInputMapping>
    <axesInputScale>     1   1   1   1   1   1 </axesInputScale>
    <axesInputShift>     0   0   0   0   0   0 </axesInputShift>
  </deviceWindow>
  <deviceGraphics id="0">
    <!-- 3d viewport initialization -->
    <float id="nearClipping">  0.1 </float>
    <float id="farClipping">   2000 </float>
    <float id="frustumLeft">  -1.0 </float>
    <float id="frustumRight">  1.0 </float>
    <float id="frustumBottom">-.75 </float>
    <float id="frustumTop">    .75 </float>
    <bool id="backFaceCulling">       1    </bool>
    <!--  camera initialization  -->
    <camera object="observer" pos="0 -3 1.6 0 0 0"/>
  </deviceGraphics>

  <!--  audio device initialization  -->
  <deviceAudio id="0" class="deviceAudioAL">      <!-- specific global settings for OpenAL -->
    <int   id="distanceModel">       1   </int>   <!-- valid arguments are NONE=0, INVERSE_DISTANCE=1 (default), INVERSE_DISTANCE_CLAMPED=2, see OpenAL ref. man. p.21 -->
    <float id="dopplerVelocity">   330.0 </float> <!-- corresponds to sonic speed for doppler effect calculations -->
    <float id="dopplerFactor">       1.0 </float> <!-- additional scaling factor for doppler effect calculations -->
  </deviceAudio>
  <!-- resource definition -->
  <resources>
    <resource mime="model/vrml" id="1"  name="virtualab"   url="resources/virtualab.wrl"/>
    <resource mime="model/vrml" id="2"  name="surface"     url="resources/virtualab_surface.wrl"/>
    <resource mime="model/vrml" id="3"  name="cube"        url="resources/box.wrl"/>
    <resource mime="model/vrml" id="5"  name="ball"        url="resources/ball01.wrl"/>
    <resource mime="image/png"  id="6"  name="veRner"      url="resources/veRner_small.png" sizeX="6" sizeY="3"/>
    <resource mime="image/png"  id="7"  name="explo"       url="resources/explo.png" sizeX="3" sizeY="3" timeSpan="1.0" loop="true" tileX="4" tileY="4" usePitch="true"/>
    <resource mime="font/txf"    id="10" name="default"    url="default.txf" size="24"/>
    <resource mime="audio/wav" id="11" loop="true" url="resources/ding.wav"/>
    <resource mime="audio/wav" id="12" pitch="1.0" loop="true" attenuationDist="3.0" url="resources/riff01.wav"/>
    <resource mime="audio/wav" id="13" pitch="1.0" loop="true" url="resources/river.wav"/>

    <container                 id="20" name="box" shape="3" sound="12"/>
    <container                 id="21" name="ufo" shape="5" sound="13"/>

  </resources>

  <!-- scene and simulation initialization -->
  <scene id="0" script="main">
    <object id="0" name="observer" script="camera.lua" input="window"/>
    <object id="1" shape="1" surface="2" pos="0 0 0"/>
    <object id="3" shape="20" sound="20" pos="-5 5 0 225 0 0"/>
    <object id="5" shape="21" sound="21" pos="2 2 2" speed="0 2 0 30 0 0"/>
    <object id="6" shape="6" pos="0 7 5"/>
    <object id="7" shape="7" pos="-4.5 4.5 1.7"/>
    <object id="11" sound="11" pos="10 -10 0"/>

    <light id="0" enabled="1" position="-.5 -.75 1.0 0.0" ambient="0.3 0.3 0.3 1.0" diffuse="0.7 0.7 0.7 1.0" specular="1.0 1.0 1.0 1.0"/>
  </scene>

</XperiML>
]]

local xlua, err = xml.decode(cxml)
log_dump("luaxml decode err: {}, xml:{}", err, xlua)
local exml = xml.encode(xlua)
log_dump("luaxml encode xml:{}", exml)

local xxlua = xml.decode(cxml)
local ok = xml.save("./bb.xml", xxlua, 'xml version="1.0" encoding="gbk"')
log_dump("luaxml save xml:{}", ok)
local flua, ferr = xml.open("./bb.xml")
log_dump("luaxml open err: {}, xml:{}", ferr, flua)

