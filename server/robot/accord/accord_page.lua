-- luacheck: ignore 631
return [[<html>
<head>
    <title>协议测试</title>
    <style type="text/css">
        pre {outline: 1px solid #ccc; }
        .string { color: green; }
        .number { color: darkorange; }
        .boolean { color: blue; }
        .null { color: magenta; }
        .key { color: red; }

        ul,
        li {
            margin: 0;
            padding: 0;
            list-style: none;
        }
        ul {
            display: block;
            list-style-type: disc;
            margin-block-start: 1em;
            margin-block-end: 1em;
            margin-inline-start: 0px;
            margin-inline-end: 0px;
            padding-inline-start: 40px;
        }
        .list-item {
            transition: transform .2s ease-out;
            width: 400px;
        }
        .add-plus-icon {
            position: relative;
            display: block;
            width: 18px;
            height: 18px;
            border: 1px solid #addaff;
            background-color: #fff;
            border-radius: 50%;
            transition: all 0.3s ease
        }
        .add-plus-icon:before,
        .add-plus-icon:after {
            content: '';
            position: absolute;
            left: 8px;
            top: 5px;
            left: 7px;
            top: 4px;
            height: 8px;
            width: 2px;
            background-color: #3c96ff
        }
        .add-plus-icon:after {
            transform: rotate(90deg)
        }
        .add-plus-icon:hover {
            border-color: #3c96ff;
            background-color: #3c96ff
        }
        .add-plus-icon:hover:before,
        .add-plus-icon:hover:after {
            background-color: #fff
        }
        .pipeline-drag {
            cursor: url(data:;base64,AAACAAEAICACAAcABQAwAQAAFgAAACgAAAAgAAAAQAAAAAEAAQAAAAAAAAEAAAAAAAAAAAAAAgAAAAAAAAAAAAAA////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD8AAAA/AAAAfwAAAP+AAAH/gAAB/8AAA//AAAd/wAAGf+AAAH9gAADbYAAA2yAAAZsAAAGbAAAAGAAAAAAAAA//////////////////////////////////////////////////////////////////////////////////////gH///4B///8Af//+AD///AA///wAH//4AB//8AAf//AAD//5AA///gAP//4AD//8AF///AB///5A////5///8=), default
        }
        .pipeline-stage {
            position: relative;
            margin: 0;
            padding-bottom: 30px
        }
        .pipeline-stage.show-stage-area .soda-process-stage:before {
            position: absolute;
            content: '';
            width: 88%;
            top: 0;
            left: 6%;
            height: 100%;
            background: #ffffff10
        }
        .soda-stage-container {
            text-align: left;
            margin: 0 41px 26px 41px;
            position: relative
        }
        .soda-stage-container .container-title {
            display: flex;
            height: 42px;
            background: #33333f;
            color: white;
            font-size: 14px;
            align-items: center;
            position: relative;
            margin: 30px 0 30px 0;
            width: 240px;
            z-index: 3
        }
        .soda-stage-container .container-title>.container-name {
            display: inline-block;
            max-width: auto;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            flex: 1;
            padding: 0 12px
        }
        .soda-stage-container .container-title>.container-name span:hover {
            color: #3c96ff
        }
        .soda-stage-container .container-title .close {
            position: relative;
            display: block;
            width: 16px;
            height: 16px;
            border: 1px solid #2E2E3A;
            background-color: #c4c6cd;
            border-radius: 50%;
            transition: all 0.3s ease;
            border: none;
            display: none;
            margin-right: 10px;
            transform: rotate(45deg);
            cursor: pointer
        }
        .soda-stage-container .container-title .close:before,
        .soda-stage-container .container-title .close:after {
            content: '';
            position: absolute;
            left: 7px;
            top: 4px;
            left: 6px;
            top: 3px;
            height: 8px;
            width: 2px;
            background-color: #2E2E3A
        }
        .soda-stage-container .container-title .close:after {
            transform: rotate(90deg)
        }
        .soda-stage-container .container-title .close:hover {
            border-color: #ff5656;
            background-color: #ff5656
        }
        .soda-stage-container .container-title .close:hover:before,
        .soda-stage-container .container-title .close:hover:after {
            background-color: #fff
        }
        .soda-stage-container .container-title .close:before,
        .soda-stage-container .container-title .close:after {
            left: 7px;
            top: 4px
        }
        .soda-stage-container .container-title:hover .close {
            display: block
        }
        .soda-stage-container .container-title:after {
            right: -41px;
            left: auto
        }
        .container-atom-list {
            position: relative;
            z-index: 3;
            margin-top: 5
        }
        .container-atom-list .atom-item {
            position: relative;
            display: flex;
            flex-direction: row;
            align-items: center;
            width: 240px;
            height: 42px;
            margin: 0 0 11px 0;
            background-color: white;
            border-radius: 2px;
            font-size: 14px;
            transition: all .4s ease-in-out;
            z-index: 2
        }
        .container-atom-list .atom-item .atom-icon {
            text-align: center;
            margin: 0 14.5px;
            font-size: 18px;
            width: 18px;
            fill: currentColor;
            color: #63656E;
        }
        .container-atom-list .atom-item:hover {
            border-color: #3c96ff
        }
        .container-atom-list .atom-item:hover .atom-icon {
            color: #3c96ff
        }
        .container-atom-list .atom-item:hover .add-plus-icon.close {
            cursor: pointer;
            color: #c3cdd7;
            display: block
        }
        .container-atom-list .atom-item:first-child:before {
            top: -16px
        }
        .container-atom-list .atom-item:before {
            content: '';
            position: absolute;
            height: 14px;
            width: 2px;
            background: #c3cdd7;
            top: -12px;
            left: 21.5px;
            z-index: 1
        }
        .container-atom-list .atom-item:after {
            content: '';
            position: absolute;
            height: 4px;
            width: 4px;
            border: 2px solid #c3cdd7;
            border-radius: 50%;
            background: white;
            top: -5px;
            left: 18.5px;
            z-index: 2
        }
        .container-atom-list .atom-item .add-plus-icon.close {
            position: relative;
            display: block;
            width: 16px;
            height: 16px;
            border: 1px solid #fff;
            background-color: #c4c6cd;
            border-radius: 50%;
            transition: all 0.3s ease;
            display: none;
            margin-right: 10px;
            border: none;
            transform: rotate(45deg)
        }
        .container-atom-list .atom-item .add-plus-icon.close:before,
        .container-atom-list .atom-item .add-plus-icon.close:after {
            content: '';
            position: absolute;
            left: 7px;
            top: 4px;
            left: 6px;
            top: 3px;
            height: 8px;
            width: 2px;
            background-color: #fff
        }
        .container-atom-list .atom-item .add-plus-icon.close:after {
            transform: rotate(90deg)
        }
        .container-atom-list .atom-item .add-plus-icon.close:hover {
            border-color: #ff5656;
            background-color: #ff5656
        }
        .container-atom-list .atom-item .add-plus-icon.close:hover:before,
        .container-atom-list .atom-item .add-plus-icon.close:hover:after {
            background-color: #fff
        }
        .container-atom-list .atom-item .add-plus-icon.close:before,
        .container-atom-list .atom-item .add-plus-icon.close:after {
            left: 7px;
            top: 4px
        }
        .container-atom-list .atom-item:hover .add-plus-icon.close.run {
            background: url(data:;base64,AAACAAEAICACAAcABQAwAQAAFgAAACgAAAAgAAAAQAAAAAEAAQAAAAAAAAEAAAAAAAAAAAAAAgAAAAAAAAAAAAAA////AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD8AAAA/AAAAfwAAAP+AAAH/gAAB/8AAA//AAAd/wAAGf+AAAH9gAADbYAAA2yAAAZsAAAGbAAAAGAAAAAAAAA//////////////////////////////////////////////////////////////////////////////////////gH///4B///8Af//+AD///AA///wAH//4AB//8AAf//AAD//5AA///gAP//4AD//8AF///AB///5A////5///8=)
        }
        .container-atom-list .atom-item>.atom-name {
            flex: 1;
            color: #63656E;
            display: inline-block;
            max-width: auto;
            overflow: hidden;
            text-overflow: ellipsis;
            white-space: nowrap;
            max-width: 188px
        }
        .container-atom-list .atom-item>.atom-name span:hover {
            color: #3c96ff
        }
        .container-atom-list .atom-section {
            margin: 0;
            width: 100%;
            height: 100%;
            border: 1px solid #c3cdd7
        }
        .container-atom-list .atom-section:before,
        .container-atom-list .atom-section:after {
            display: none
        }
        .container-atom-list .add-atom-entry {
            position: absolute;
            bottom: -10px;
            left: 111px;
            background-color: white;
            cursor: pointer;
            z-index: 3
        }
        .container-atom-list .add-atom-entry .add-plus-icon {
            position: relative;
            display: block;
            width: 18px;
            height: 18px;
            border: 1px solid #c3cdd7;
            background-color: #fff;
            border-radius: 50%;
            transition: all 0.3s ease
        }
        .container-atom-list .add-atom-entry .add-plus-icon:before,
        .container-atom-list .add-atom-entry .add-plus-icon:after {
            content: '';
            position: absolute;
            left: 8px;
            top: 5px;
            left: 7px;
            top: 4px;
            height: 8px;
            width: 2px;
            background-color: #c3cdd7
        }
        .container-atom-list .add-atom-entry .add-plus-icon:after {
            transform: rotate(90deg)
        }
        .container-atom-list .add-atom-entry .add-plus-icon:hover {
            border-color: #3c96ff;
            background-color: #3c96ff
        }
        .container-atom-list .add-atom-entry .add-plus-icon:hover:before,
        .container-atom-list .add-atom-entry .add-plus-icon:hover:after {
            background-color: #fff
        }
        .container-atom-list .add-atom-entry:hover {
            border-color: #3c96ff;
            color: #3c96ff
        }
        .blue {
            background-color: #3c96ff !important;
        }
        .light-blue {
            background-color: #3cffff !important;
        }
        .gray {
            background-color: #515252 !important;
            pointer-events: none;
            cursor: default;
        }
        .light-gray {
            background-color: #c1d8d8 !important;
            color: #2a313a !important;
        }
        .green {
            background: #27d99f !important;
        }
        .light-green {
            background: #4cfbc1 !important;
        }
        .stage-status {
            position: relative;
            text-align: center;
            overflow: hidden;
            font-size: 16px;
            width: 42px;
            height: 42px;
            line-height: 42px;
            box-sizing: border-box;
            background-color: #65686b;
        }
        .login-button {
            width: 270px;
            height: 40px;
            border-width: 0px;
            border-radius: 3px;
            background: #515252;
            cursor: pointer;
            outline: none;
            font-family: Microsoft YaHei;
            color: white;
            font-size: 17px;
        }
        .login-button:hover {
            background: #5599FF;
        }
        .login-button.run-button {
            background: #27d99f;
            width: 240px;
            margin-left: 80px;
        }
        .login-button.save-button {
            margin-top: 20px;
            background: #27d99f;
        }
        .left-pad {
            padding-left: 60px;
        }
        .left-half {
            margin-top: 20px;
            width: 400px;
            float: left;
        }
        .right-half {
            width: calc(100% - 420px);
            float: left;
            border-left: 1px solid rgb(15, 44, 56);
            overflow-x: scroll;
            padding-left: 20px;
            box-sizing: border-box;
        }
        .p-style {
            white-space: pre;
            margin: 0;
        }
        html,
        body {
            height: calc(100% - 5px);
        }
        .log-half {
            width: calc(100% - 440px);
            height: calc(100% - 20px);
            overflow-y: auto;
            float: left;
            border: 1px solid rgb(15, 44, 56);
            padding-bottom: 20px;
            box-sizing: border-box;
            white-space: pre-line;
        }
        .log-item {
            width: 95%;
            overflow: hidden;
            display: block;
            margin: 20px auto 0;
            border: 2px solid rgb(58, 58, 58);
            position: relative;
        }
        .tool-btn {
            outline: none;
            margin-right: 10px;
            border-radius: 5px;
        }
        .log-sub-item {
            width: 50%;
            height: auto;
            float: left;
            overflow-x: auto;
        }
        .log-divider-line {
            height: auto;
            top: 0;
            bottom: 0;
            left: 50%;
            right: 50%;
            position: absolute;
            width: 1px;
            float: left;
            border-left: 2px solid rgb(58, 58, 58);
        }
        .bk-form-row {
            clear: both;
            display: flex;
            align-items: flex-start;
            margin-top: 8px
        }
        .bk-form-row .bk-form-inline-item {
            flex: 1;
            padding: 0 12px 0 0;
            justify-content: space-between
        }
        .bk-form-inline-item {
            display: inline-block;
            vertical-align: top
        }
        .bk-form-row {
            display: flex
        }
        .bk-form-row .bk-form-item {
            flex: 1
        }
        .bk-button {
            height: 32px;
            line-height: 30px;
            display: inline-block;
            outline: none;
            cursor: pointer;
            white-space: nowrap;
            -webkit-appearance: none;
            padding: 0 15px;
            text-align: center;
            vertical-align: middle;
            font-size: 14px;
            background-color: #fff;
            border: 1px solid #c4c6cc;
            border-radius: 2px;
            -webkit-box-sizing: border-box;
            box-sizing: border-box;
            color: #63656e;
            text-decoration: none;
            -webkit-transition: background-color .3s ease;
            transition: background-color .3s ease;
            min-width: 68px;
            position: relative
        }
        .bk-icon {
            font-family: bk !important;
            font-style: normal;
            font-weight: 400;
            -webkit-font-feature-settings: normal;
            font-feature-settings: normal;
            font-variant: normal;
            text-transform: none;
            line-height: 1;
            text-align: center;
            -webkit-font-smoothing: antialiased;
            -moz-osx-font-smoothing: grayscale;
        }
        .icon-angle-down:before {
            content: "<"
        }
        .icon-angle-right:before {
            content: ">"
        }
        .bk-form.bk-form-vertical .bk-label {
            width: auto;
            text-align: left
        }
        .bk-form.bk-form-vertical .bk-form-content {
            clear: both;
            margin-left: 0 !important
        }
        .bk-form.bk-form-vertical .bk-form-item+.bk-form-item {
            margin-top: 8px
        }
        .bk-form .bk-label {
            width: 150px;
            min-height: 32px;
            text-align: right;
            vertical-align: middle;
            line-height: 32px;
            float: left;
            font-size: 14px;
            font-weight: 400;
            color: #63656e;
            -webkit-box-sizing: border-box;
            box-sizing: border-box;
            padding: 0 24px 0 0
        }
        .bk-form .bk-form-content {
            width: auto;
            min-height: 32px;
            margin-left: 150px;
            position: relative;
            outline: none;
            line-height: 30px
        }
        .bk-form .bk-form-item:before,
        .bk-form:after {
            display: table;
            content: "";
            clear: both;
            visibility: hidden;
            font-size: 0
        }
        .bk-form-item {
            position: relative
        }
        .bk-form-input {
            -webkit-box-sizing: border-box;
            height: 32px;
            line-height: normal;
            color: #63656e;
            background-color: #fff;
            border-radius: 2px;
            width: 100%;
            font-size: 12px;
            font-size: var(--font-size);
            box-sizing: border-box;
            border: 1px solid #c4c6cc;
            padding: 0 10px;
            text-align: left;
            vertical-align: middle;
            outline: none;
            resize: none;
            -webkit-transition: border .2s linear;
            transition: border .2s linear
        }
        .bk-form-input:focus {
            border-color: #3a84ff !important;
            background-color: #fff !important
        }
        .bk-sideslider {
            position: fixed;
            top: 0;
            right: 0;
            bottom: 0;
            left: 0;
            z-index: 2500
        }
        .bk-sideslider-wrapper {
            position: absolute;
            top: 0;
            bottom: 0;
            background-color: #fff;
            overflow-y: auto
        }
        .bk-sideslider-wrapper.right {
            right: 0
        }
        .bk-sideslider-header {
            width: 100%;
            height: 60px;
            background: #fff
        }
        .bk-sideslider-header:after,
        .bk-sideslider-header:before {
            content: "";
            display: table;
            line-height: 0
        }
        .bk-sideslider-header:after {
            clear: both
        }
        .bk-sideslider-closer {
            width: 30px;
            height: 60px;
            line-height: 60px;
            background-color: #3a84ff;
            text-align: center;
            color: #fff;
            cursor: pointer;
            font-size: 24px;
        }
        .bk-sideslider-title {
            height: 60px;
            line-height: 30px;
            border-bottom: 1px solid #dcdee5;
            font-size: 16px;
            font-weight: 700;
            color: #666
        }
        .bk-sideslider-content {
            overflow: auto
        }
        .atom-property-panel {
            height: 100%
        }
        .bkci-property-panel .bk-sideslider-content {
            height: calc(100% - 60px);
            max-height: calc(100vh - 60px)
        }
        .atom-property-panel {
            font-size: 14px;
            height: calc(100% - 60px);
            overflow: hidden;
            padding: 20px 32px 10px 32px
        }
        .atom-property-panel .atom-main-content {
            height: 100%;
            display: flex;
            flex-direction: column
        }
        .atom-property-panel .atom-main-content .atom-form-content {
            flex: 1;
            overflow: auto
        }
        .atom-property-panel .atom-type-selector {
            display: flex;
            margin-bottom: 20px;
            padding-bottom: 25px;
            border-bottom: 1px solid #ebf0f5
        }
        .bkci-property-panel {
            font-size: 14px
        }
        .soda-accordion {
            border: 1px solid #ebf0f5;
            border-radius: 3px;
            margin: 12px 0;
            font-size: 12px
        }
        .soda-accordion .header {
            display: flex;
            color: #7b7d8a;
            background-color: white;
            padding: 10px 15px;
            align-items: center;
            cursor: pointer
        }
        .soda-accordion .header .icon-angle-down {
            display: block;
            margin: 2px 12px 0 0;
            transition: all 0.3s ease
        }
        .soda-accordion .header[active] .icon-angle-down {
            transform: rotate(-180deg)
        }
        .soda-accordion .content {
            padding: 10px 15px
        }
        .soda-accordion.showCheckbox>.header {
            background-color: #63656E;
            color: white
        }
        .soda-accordion.showCheckbox>.header .devops-icon {
            display: none
        }
        .soda-accordion.showCheckbox>.header .var-header {
            width: 100%;
            display: flex;
            align-items: center;
            justify-content: space-between
        }
        .property-panel-header {
            font-size: 14px;
            font-weight: normal;
            display: flex;
            justify-content: space-between;
            align-items: center;
            height: 60px;
            width: calc(100% - 30px);
            border-bottom: 1px solid #e6e6e6
        }
        .reference-var {
            color: #3c96ff;
            padding: 10px
        }
        .reference-var>span {
            cursor: pointer
        }
        .hidden {
            display: none;
        }
        .input-textarea {
            width: 100%;
            height: 250px;
            outline: 0;
            border: 1px solid #a0b3d6;
            font-size: 14px;
            color: #666;
            line-height: 22px;
            padding: 2px;
            white-space: nowrap;
            overflow-x: auto;
            overflow-y: auto;
            font-family: Microsoft YaHei;
        }
        .center-box {
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .pipeline-stage .pipeline-stage-entry {
            display: block;
            width: 88%;
            left: 6%;
            height: 50px;
            line-height: 50px;
            background-color: #515252;
            border-color: #414448;
            color: #c8d1dc;
            z-index: 2;
        }
        .stage-container {
            width: 100%;
            overflow: hidden;
            display: block;
            position: relative;
        }
        .stage-content {
            height: auto;
            float: left;
        }
        .heartbeat-icon {
            float: right;
            margin-top: 16px;
            width: 18px;
            height: 18px;
            border: 1px solid #9e9e9e;
            background-color: #a9a9a9;
            border-radius: 50%;
            transition: all 0.3s ease
        }
        .pad-line {
            display: block;
            border: 1px solid #36393c;
            width: 88%;
            left: 6%;
            position: absolute;
        }
    </style>
    <meta charset="utf-8">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.8.3/angular.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/downloadjs/1.4.8/download.min.js"></script>
</head>
<body>
<div ng-app="robot" ng-controller="protocol">
    <div class="left-half">
        <div class="show-stage-area pipeline-stage">
            <button type="button" class="bk-button-normal bk-button pipeline-stage-entry light-gray" ng-click="setupTestCase()">
                <div class="center-box">
                    <div class="stage-content">{{curCaseName}}</div>
                </div>
            </button>
            <div class="left-pad">
                <p>服务器地址: {{serverAddr}}</p>
                <p>OpenID: {{openid}}</p>
            </div>
            <div class="pad-line"></div>
        </div>
        <div ng-show="showOperator" class="list-item pipeline-drag show-stage-area pipeline-stage">
            <button type="button" class="bk-button-normal bk-button pipeline-stage-entry light-gray">
                <div class="stage-container">
                    <div class="stage-content">{{robotStatus}}</div>
                    <div id="heartbeat-light" class="heartbeat-icon light-gray"></div>
                </div>
            </button>
            <ul class="soda-process-stage">
                <div class="soda-stage-container">
                    <h3 class="container-title first-ctitle">
                        <span id="start-btn" class="stage-status container blue" ng-click="startRobot()">启动</span>
                        <p class="container-name" ng-click="startRobot()"><span id="start-text">启动Robot</span></p>
                    </h3>
                    <span class="add-atom-entry" ng-show="caseNew"><i class="add-plus-icon" ng-click="addItem(cmd)"></i></span>
                    <section style="overflow-y: auto;height:250">
                        <div class="container-atom-list" ng-repeat="cmd in curProtocols" id="case_protocols">
                            <li class="atom-item">
                                <section class="atom-item atom-section normal-atom">
                                    <svg width="18" height="18" viewBox="0 0 32 32" class="atom-icon" ng-click="showProtocol(false, cmd)">
                                        <path d="M25.82 4H23c0-1.1-.98-2-2.2-2h-.2c0-1.1-.98-2-2.2-2h-4.8c-1.22 0-2.2.9-2.2 2h-.2C9.98 2 9 2.9 9 4H6.18C4.42 4 3 5.34 3 7v22c0 1.66 1.42 3 3.18 3h19.64c1.76 0 3.18-1.34 3.18-3V7c0-1.66-1.42-3-3.18-3zM11.2 4h1.2c.56 0 1-.44 1-1l-.02-.92c.02-.02.08-.08.22-.08h4.8c.12 0 .2.04.2.02V3c0 .56.44 1 1 1h1.2c.12 0 .2.04.2.02v1l.02 2.9c-.02.02-.08.08-.22.08h-9.6c-.08 0-.16-.02-.18-.02S11 7.98 11 8l-.02-2.94c0-.02.02-.04.02-.06s-.02-.04-.02-.08v-.86c.02 0 .08-.06.22-.06zM27 29c0 .56-.52 1-1.18 1H6.18C5.52 30 5 29.56 5 29V7c0-.56.54-1 1.18-1H9v2c0 1.1.98 2 2.2 2h9.6c1.22 0 2.2-.9 2.2-2V6h2.82c.66 0 1.18.44 1.18 1v22z"></path><path d="M22 16H10c-.56 0-1 .44-1 1s.44 1 1 1h12c.56 0 1-.44 1-1s-.44-1-1-1zM22 20H10c-.56 0-1 .44-1 1s.44 1 1 1h12c.56 0 1-.44 1-1s-.44-1-1-1zM22 24H10c-.56 0-1 .44-1 1s.44 1 1 1h12c.56 0 1-.44 1-1s-.44-1-1-1z"></path>
                                    </svg>
                                    <p class="atom-name" ng-click="showProtocol(false, cmd)"><span>{{cmd.name}}</span></p>
                                    <i class="add-plus-icon close run" ng-click="runProtocol(cmd)"></i>
                                    <i class="add-plus-icon close" ng-click="removeItem(cmd)"></i>
                                </section>
                            </li>
                            <span class="add-atom-entry"><i class="add-plus-icon" ng-click="addItem(cmd)"></i></span>
                        </div>
                    </section>
                    <h3 class="container-title first-ctitle">
                        <span id="stop-btn" class="stage-status container" ng-click="stopRobot()">停止</span>
                        <p class="container-name" ng-click="stopRobot()"><span id="stop-text">停止Robot</span></p>
                    </h3>
                </div>
            </ul>
            <button id="runall-btn" class="add-plus-icon login-button run-button" ng-click="runAll()">Run All</button><br>
            <button id="runall-btn" class="add-plus-icon login-button run-button" ng-click="messageFilter()">消息筛选</button><br>
            <button id="runall-btn" class="add-plus-icon login-button run-button" ng-click="saveCaseData()">保存</button><br>
            <button id="runall-btn" class="add-plus-icon login-button run-button" ng-click="cleanLogs()">清空控制台</button>
        </div>
    </div>
    <div class="log-half" id="message_content">
       <pre id="jsonShow">  {{messages}}</pre>
    </div>
    <article id="side-protocol" class="bk-sideslider bkci-property-panel" style="z-index: 2021;" ng-show="protoShow">
        <section class="bk-sideslider-wrapper right" style="width: 600px;">
            <div class="bk-sideslider-header">
                <i class="bk-sideslider-closer" style="float: left;" ng-click="showProtocol(false)">
                    <i class="bk-icon icon-angle-right"></i>
                </i>
                <div class="bk-sideslider-title" style="padding: 0px 0px 0px 50px;">
                    <header class="property-panel-header">
                        <div><p>{{curProtocolName.name}}</p></div>
                    </header>
                </div>
            </div>
            <div class="bk-sideslider-content" style="max-height: calc(100vh - 30px); position: relative;">
                <section class="atom-property-panel">
                    <div class="atom-main-content" style="position: relative;">
                        <div class="atom-form-content">
                            <div class="atom-form-box">
                                <section class="bk-form bk-form-vertical atom-content" atom="[object Object]">
                                    <div class="form-field bk-form-item is-required">
                                        <label ng-show="protoNew" class="bk-label atom-form-label">选择协议:</label>
                                        <select ng-show="protoNew" class="bk-form-input" ng-model="curProtocolName" ng-change="addProtoChange(curProtocolName)" ng-options="v.name for (k, v) in protocols | orderBy:'name' " ></select>
                                        <label class="bk-label atom-form-label">协议参数：</label>
                                        <div class="bk-form-content">
                                            <textarea id="parameter" name="parameter" ng-model="curProtocolArgs"
                                                class="input-textarea">{{curProtocolArgs}}</textarea>
                                        </div><br>
                                        <div class="center-box">
                                            <button class="add-plus-icon login-button" ng-click="modifyProtoData()" ng-hide="protoNew">保存</button>
                                            <button class="add-plus-icon login-button" ng-click="insertProtoData()" ng-show="protoNew">确定</button>
                                        </div>
                                    </div>
                                </section>
                            </div>
                        </div>
                    </div>
                </section>
            </div>
        </section>
    </article>

    <article class="bk-sideslider bkci-property-panel" style="z-index: 2021;" ng-show="messageFilterShow">
        <section class="bk-sideslider-wrapper right" style="width: 600px;">
            <div class="bk-sideslider-header">
                <i class="bk-sideslider-closer" style="float: left;" ng-click="showMessageFilter(false)">
                    <i class="bk-icon icon-angle-right"></i>
                </i>
            </div>
            <div class="bk-sideslider-content" style="max-height: calc(100vh - 30px); position: relative;">
                <section class="atom-property-panel">
                    <div class="atom-main-content" style="position: relative;">
                        <div class="atom-form-content">
                            <div class="atom-form-box">
                                <section class="bk-form bk-form-vertical atom-content" atom="[object Object]">
                                    <div class="form-field bk-form-item is-required">
                                        <label ng-show="protoNew" class="bk-label atom-form-label">选择协议:</label>
                                        <label class="bk-label atom-form-label">消息筛选(格式:逗号分割)(例如:10000,10001)</label>
                                        <div class="bk-form-content">
                                            <textarea id="parameter" name="parameter" ng-model="messageFilterText"
                                                class="input-textarea">{{messageFilterText}}</textarea>
                                        </div><br>
                                        <div class="center-box">
                                            <button class="add-plus-icon login-button" ng-click="modifyProtFilter()" ng-hide="protoNew">保存</button>
                                        </div>
                                    </div>
                                </section>
                            </div>
                        </div>
                    </div>
                </section>
            </div>
        </section>
    </article>

    <article id="side-case" class="bk-sideslider bkci-property-panel" style="z-index: 2021;" ng-show="caseShow">
        <section class="bk-sideslider-wrapper right" style="width: 600px;">
            <div class="bk-sideslider-header">
                <i class="bk-sideslider-closer" style="float: left;" ng-click="showCase(false)">
                    <i class="bk-icon icon-angle-right"></i>
                </i>
                <div class="bk-sideslider-title" style="padding: 0px 0px 0px 50px;">
                    <header class="property-panel-header">
                        <div><p>配置测试用例</p></div>
                    </header>
                </div>
            </div>
            <div class="bk-sideslider-content" style="max-height: calc(100vh - 30px); position: relative;">
                <section class="atom-property-panel">
                    <div class="atom-main-content" style="position: relative;">
                        <div class="atom-form-content">
                            <div class="atom-form-box">
                                <section class="bk-form bk-form-vertical atom-content" atom="[object Object]">
                                    <label class="bk-label atom-form-label">新建测试用例:</label>
                                    <input type="checkbox" ng-model="caseNew" ng-change="newCase()">
                                    <div style="width: 100%; height: 30px;"></div>
                                    <label class="bk-label atom-form-label">上传本地配置:</label>
                                    <input type="file" accept=".lua" class="bk-form-input" onchange="angular.element(this).scope().uploadFile(this.files)"/>
                                    <label ng-show="caseNew" class="bk-label atom-form-label">输入用例名称:</label>
                                    <input ng-show="caseNew" type="text" class="bk-form-input" ng-model="curCaseName"></input>
                                    <label ng-hide="caseNew" class="bk-label atom-form-label">选择测试用例:</label>
                                    <select ng-hide="caseNew" class="bk-form-input" ng-model="curCase" ng-options="key for (key, value) in tescases" ng-change="changeCases()"></select>
                                    <label class="bk-label atom-form-label">选择服务器:</label>
                                    <select class="bk-form-input" ng-model="serverAddr" ng-options="x for x in servers"></select>
                                    <label class="bk-label atom-form-label">输入OPENID:</label>
                                    <input type="text" class="bk-form-input" ng-model="openid"></input>
                                    <label class="bk-label atom-form-label">输入密码:</label>
                                    <input type="text" class="bk-form-input" ng-model="passwd"></input>
                                    <div class="center-box" style="width: 100%;height: 80px;">
                                        <button class="add-plus-icon login-button" ng-click="showCase(false)" ng-hide="caseNew">确定</button>
                                        <button class="add-plus-icon login-button" ng-click="insertCase()" ng-show="caseNew">确定</button>
                                    </div>
                                    <div class="center-box" style="width: 100%;height: 80px;">
                                        <button class="add-plus-icon login-button" ng-click="uploadLocal()" ng-show="upload">上传</button>
                                    </div>
                                </section>
                            </div>
                        </div>
                    </div>
                </section>
            </div>
        </section>
    </article>
</div>
</body>
<script>
    var app = angular.module('robot', [])
    app.controller('protocol', function($scope, $http, $interval) {
        $scope.openid = null
        $scope.passwd = null
        $scope.logined = false
        $scope.caseShow = false
        $scope.protoShow = false
        $scope.messageFilterShow = false
        $scope.serverAddr = null
        $scope.robotStatus ="未启动"
        $scope.showOperator = false
        $scope.protoNew = false
        $scope.caseNew = false
        $scope.upload = false
        $scope.uploadConfig = {}

        //测试用例
        $scope.curCase = null
        $scope.curCaseName = "请配置测试用例"
        $scope.curProtocols = null
        $scope.curProtocolName = null
        $scope.curProtocolArgs = "{\n\}"
        $scope.messageFilterText = ""
        $scope.messages = ""
        //全局信息
        $scope.protocols = []
        $scope.tescases = []
        $scope.servers = []
        $scope.messageFilters = {}

        //当前插入新协议的索引
        $scope.newProtoIndex = 0;
        //新增协议选中
        $scope.addProtoChange = function(protoIndex){
            $scope.curProtocolArgs = JSON.stringify(protoIndex.fields,null,2)
        }
        //初始化
        $http.get('/config').then(function(response) {
            console.log("config", response.data)
            $scope.servers = response.data.servers
            //对象转数组
            $scope.protocols = Object.values(response.data.accord)
            //$scope.protocols = response.data.accord
            $scope.tescases = response.data.cases
            //初始化协议序号
            for(var usecase in $scope.tescases) {
                for(var index=0; index< $scope.tescases[usecase].protocols.length;index++) {
                    var proto = $scope.tescases[usecase].protocols[index]
                    proto.index = index
                }
            }
        });
        $scope.prettyFormat = function(str) {
            try {
                // 去除JSON.stringify带来的hashkey
                str.$$hashKey = undefined
                // 设置缩进为2个空格
                str = JSON.stringify(str, null, 2);
                str = str
                    .replace(/&/g, '&amp;')
                    .replace(/</g, '&lt;')
                    .replace(/>/g, '&gt;');
                return str.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, function (match) {
                    var cls = 'number';
                    if (/^"/.test(match)) {
                        if (/:$/.test(match)) {
                            cls = 'key';
                        } else {
                            cls = 'string';
                        }
                    } else if (/true|false/.test(match)) {
                        cls = 'boolean';
                    } else if (/null/.test(match)) {
                        cls = 'null';
                    }
                    return '<span class="' + cls + '">' + match + '</span>';
                });
            } catch (e) {
                alert("异常信息:" + e);
            }
        }
        //定时器
        $interval(function(){
            if ($scope.logined) {
                //处理滚动条
                var divscll = document.getElementById('message_content');
                divscll.scrollTop = divscll.scrollHeight;
                //发送心跳
                $scope.runHeartBeat()
                //获取服务器推送消息
                $http.get('/message',{
                    params:{
                    "open_id":  $scope.openid
                    }
            }).then(function(response) {
                    console.log("message", response.data)
                    if(response.data.hasOwnProperty("msg") &&  Object.keys(response.data.msg).length != 0){
                        var append = true
                        if(Object.getOwnPropertyNames($scope.messageFilters).length > 0){
                            var cmd_id = response.data.msg.cmd_id;
                            if(!$scope.messageFilters[cmd_id]){
                                append = false
                            }
                        }
                        if(append){
                            $scope.messages += "\n\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]服务器通知:\n"+$scope.prettyFormat(response.data)
                            document.getElementById('jsonShow').innerHTML = $scope.messages
                        }
                    }
                });
            }
        }, 1000*1);
        //成员函数
        $scope.showProtocol=function(isNew, cmd){
            $scope.protoNew = isNew
            $scope.protoShow = cmd ? true : false;
            if(cmd){
                $scope.curProtocolName = cmd
                $scope.curProtocolArgs = JSON.stringify(cmd.args, null, "    ")
            }
        }
        //成员函数
        $scope.showMessageFilter=function(value){
            $scope.messageFilterShow = value
        }
        $scope.uploadLocal= function(){
            $http.post('/upload',{
                "data": $scope.uploadConfig
            }).then(function(response) {
                if(response){
                    alert("上传成功")
                    console.log("config", response.data)
                    $scope.servers = response.data.servers
                    $scope.protocols = response.data.accord
                    $scope.tescases = response.data.cases
                    //初始化协议序号
                    for(var usecase in $scope.tescases) {
                        for(var index=0; index< $scope.tescases[usecase].protocols.length;index++) {
                            var proto = $scope.tescases[usecase].protocols[index]
                            proto.index = index
                        }
                    }
                }
            },function(response){
                alert("上传失败")
            });
        }
        $scope.showCase=function(isShow){
            $scope.caseShow = isShow
            if(!isShow && $scope.logined){
                //暂停机器人
                $scope.stopRobot()
            }
        }
        $scope.uploadFile=function(files) {
            console.log("uploadFile", files)
            var reader = new FileReader();
            reader.onload = function(){
                if(reader.result){
                    try {
                        $scope.uploadConfig = reader.result
                        $scope.showOperator = true
                        $scope.upload = true
                    } catch(err) {
                        alert("加载文件失败 "+ err)
                    }
                }
            }
            reader.readAsText(files[0])
        }

        //保存测试用例
        $scope.saveCaseData=function(){
            var protocols = "{\n";
            var curProtoIndex = 1
            for(var protoIndex in $scope.curProtocols) {
                var proto = $scope.curProtocols[protoIndex]
                if(!proto){
                    continue
                }
                protocols += "        {\n"
                protocols += "            id = "
                protocols += proto.id
                protocols += ",\n"

                protocols += "            name = "
                protocols += "'"
                protocols += proto.name
                protocols += "',\n"

                protocols += "            args = {"
                //组装参数
                //keys
                var curArgIndex = 1
                for(var key in proto.args){
                    protocols += key
                    protocols += " = "
                    //TODO value为字符串的时候需要处理与否
                    if((typeof proto.args[key]) == "string") {
                        protocols += "'"
                    }
                    protocols += proto.args[key]
                    if((typeof proto.args[key]) == "string") {
                        protocols += "'"
                    }
                    if(curArgIndex != Object.keys(proto.args).length){
                        protocols += ","
                    }
                    curArgIndex++
                }
                protocols += "}\n"
                protocols += "        }"
                if(curProtoIndex != Object.keys($scope.curProtocols).length)
                {
                    protocols += ",\n"
                }
                curProtoIndex++
            }
        protocols+="\n    }"
        var content = "return {\n\
        name = '"+$scope.curCaseName+"',\n\
        openid = '"+$scope.openid+"',\n\
        password = '"+$scope.passwd+"',\n\
        server = '"+$scope.serverAddr+"',\n\
        protocols = "+ protocols + "\n}";
            download(content, $scope.curCaseName+".lua", "text/plain");
        }
        //修改协议参数
        $scope.modifyProtoData=function(){
            var newProtocol = $scope.curProtocols[$scope.newProtoIndex]
            if($scope.curProtocolArgs){
                try {
                    newProtocol.args= JSON.parse($scope.curProtocolArgs)
                }catch(err) {
                   alert("参数错误"+err)
                   return
                }
            }else{
                newProtocol.args= {}
            }
            $scope.protoShow = false;
            console.log(JSON.stringify(newProtocol,null,2))
        }
        //修改筛选参数
        $scope.modifyProtFilter=function(){
            $scope.messageFilters = {}
            var cmds = $scope.messageFilterText.split(",")
            for(var i=0; i<cmds.length; i++){
                var cmd_id_s = cmds[i].split("-")
                if(cmd_id_s.length <= 2){
                    if(cmd_id_s.length == 1){
                        var cmd_id = parseInt(cmd_id_s[0])
                        console.log("1--cmd_id=%d",cmd_id)
                        if(cmd_id){
                            $scope.messageFilters[cmd_id] = cmd_id;
                        }
                    }else{
                        var s_cmd_id = parseInt(cmd_id_s[0])
                        var e_cmd_id = parseInt(cmd_id_s[1])
                        for (var id=s_cmd_id; id<=e_cmd_id; id++){
                            $scope.messageFilters[id] = id;
                            console.log("2--id=%d",id)
                        }
                    }
                }
            }
            console.log($scope.messageFilters)
            $scope.showMessageFilter(false)
        }
        //新增协议
        $scope.insertProtoData=function(){
            //读取输入
            var newProtocol = new Object()
            newProtocol.id = $scope.curProtocolName.msg_id
            newProtocol.name= $scope.curProtocolName.name
            if($scope.curProtocolArgs){
                try {
                    newProtocol.args= JSON.parse($scope.curProtocolArgs)
                }catch(err) {
                   alert("参数错误"+err)
                   return
                }
            }else{
                newProtocol.args= {}
            }
            if($scope.curProtocols){
                $scope.curProtocols.splice($scope.newProtoIndex +1,0,newProtocol)
            }else{
                $scope.curProtocols = new Array(newProtocol)
            }
            //默认添加下一个
            $scope.newProtoIndex +=2
            //重新排序计算序号
            for(var index=0; index< $scope.curProtocols.length;index++)
            {
                var proto = $scope.curProtocols[index]
                proto.index = index
            }
        }
        //添加测试用例
        $scope.insertCase=function(){
            $scope.showOperator = true
        }
        //新建测试用例
        $scope.newCase=function(){
            $scope.openid = null
            $scope.passwd = null
            $scope.serverAddr = null
            $scope.curCaseName = null
            $scope.curProtocols = null
        }
        $scope.changeCases=function(){
            $scope.showOperator = true
            $scope.openid = $scope.curCase.openid
            $scope.passwd = $scope.curCase.password
            $scope.serverAddr = $scope.curCase.server
            $scope.curCaseName = $scope.curCase.name
            $scope.curProtocols = $scope.curCase.protocols
        }
        //控制台日志日期格式
        Date.prototype.Format = function (fmt) {
            var o = {
                "M+": this.getMonth() + 1, // 月份
                "d+": this.getDate(), // 日
                "h+": this.getHours(), // 小时
                "m+": this.getMinutes(), // 分
                "s+": this.getSeconds(), // 秒
                "q+": Math.floor((this.getMonth() + 3) / 3), // 季度
                "S": this.getMilliseconds() // 毫秒
            };
            if (/(y+)/.test(fmt))
                fmt = fmt.replace(RegExp.$1, (this.getFullYear() + "").substr(4 - RegExp.$1.length));
            for (var k in o)
                if (new RegExp("(" + k + ")").test(fmt)) fmt = fmt.replace(RegExp.$1, (RegExp.$1.length == 1) ? (o[k]) : (("00" + o[k]).substr(("" + o[k]).length)));
                    return fmt;
        }
        //心跳
        $scope.runHeartBeat=function(){
            var cmd={}
            var heartArgs={}
            heartArgs.time = 0
            cmd.id=1001;
            cmd.args=heartArgs;
            $http.post('/run',{
                "open_id":  $scope.openid,
                "cmd_id":cmd.id,
                "data": cmd.args
            }).then(function(response) {
                if(response.data.code != 0)
                {
                    return
                }
            },function(response){
                console.log("请求处理失败",response.data)
            });
        }
        //运行单条协议
        $scope.runProtocol=function(cmd){
            if(!$scope.logined){
                alert("尚未启动")
                return;
            }
            $scope.messages+= "\n\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]发送:\n"+ $scope.prettyFormat(cmd)
            document.getElementById('jsonShow').innerHTML = $scope.messages
            $http.post('/run',{
                "open_id":  $scope.openid,
                "cmd_id":cmd.id,
                "data": cmd.args
            }).then(function(response) {
                $scope.messages +=  "\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]应答:\n"+ $scope.prettyFormat(response.data)
                document.getElementById('jsonShow').innerHTML = $scope.messages
                if(response.data.code != 0) {
                    return
                }
            },function(response){
                $scope.messages += "\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]应答:\n"+ $scope.prettyFormat(response.data)
            });
        }
        $scope.runAll=function(cmd){
            if(!$scope.logined){
                alert("尚未启动")
                return;
            }
            $scope.messages +=  "\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]请求:\n"+  $scope.prettyFormat($scope.curProtocols)
            document.getElementById('jsonShow').innerHTML = $scope.messages
            $http.post('/runall',{
                "data": $scope.curProtocols,
                "open_id":  $scope.openid
            }).then(function(response) {
                console.log("请求发送成功 应答", response.data)
                $scope.messages +=  "\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]应答:\n"+  $scope.prettyFormat(response.data)
                document.getElementById('jsonShow').innerHTML = $scope.messages
                if(response.data.code != 0){
                    //alert("请求处理失败"+ response.data.msg)
                    //回显
                    return
                }
            },function(response){
                console.log("请求处理失败",response.data)
                $scope.messages += "\n["+new Date().Format("yyyy-MM-dd hh:mm:ss S")+"]应答:"+  $scope.prettyFormat(response.data)
            });
        }
        $scope.startRobot=function(cmd){
            if($scope.logined){
                alert("已启动");
                return;
            }
            $scope.messages += "\n开始启动机器人"
            //解析ip和port
            var ipInfo = $scope.serverAddr.split(":");
            $http.post('/create',{
                    "ip":ipInfo[0],
                    "port":Number(ipInfo[1]) ,
                    "open_id":  $scope.openid,
                    "passwd":$scope.passwd
            }).then(function(response) {
                if(response.data.code != 0)
                {
                    alert("启动失败"+ response.data.msg)
                    $scope.messages += "\n启动失败"+ response.data.msg
                    return
                }
                console.log("启动成功")
                $scope.logined = true
                $scope.toggleStatus()
            },function(response){
                alert("启动失败"+response.data)
            });
        }
        $scope.stopRobot=function(cmd){
            if(!$scope.logined){
                alert("尚未启动");
                return;
            }
            //发送请求
            $http.post('/destory',{
                "open_id":  $scope.openid
            }).then(function(response) {
                if(response.data.code != 0){
                    alert("停止失败"+ response.data.msg)
                    $scope.messages += "\n停止失败"+ response.data.msg
                    document.getElementById('jsonShow').innerHTML = $scope.messages
                    return
                }
                $scope.logined = false
                $scope.toggleStatus()
            },function(response){
                alert("停止失败"+response.data)
            });
        }
        $scope.addItem=function(cmd){
            $scope.curProtocolName = null
            $scope.curProtocolArgs = "{\n\}"
            $scope.showProtocol(true, {})
            if(cmd){
                $scope.newProtoIndex = cmd.index
            }else{
                $scope.newProtoIndex = 0
            }
        }
        $scope.removeItem=function(cmd){
            console.log("removeItem", cmd)
            $scope.curProtocols.splice(cmd.index,1)
        }
        $scope.messageFilter=function(cmd){
            $scope.showMessageFilter(true)
        }
        $scope.cleanLogs=function(cmd){
            $scope.messages = ""
            document.getElementById('jsonShow').innerHTML = $scope.messages
        }
        $scope.setupTestCase=function(){
            $scope.caseShow = true
        }
        $scope.toggleStatus=function(){
            if($scope.logined){
                $scope.messages +="\n启动成功"
                $scope.robotStatus = "运行中"
                document.getElementById("heartbeat-light").className = "heartbeat-icon light-green"
                document.getElementById('jsonShow').innerHTML = $scope.messages
            }else{
                $scope.messages +="\n停止成功"
                $scope.robotStatus = "已停止"
                document.getElementById("heartbeat-light").className = "heartbeat-icon light-gray"
                document.getElementById('jsonShow').innerHTML = $scope.messages
            }
        }
    });
</script>
</html>]]
