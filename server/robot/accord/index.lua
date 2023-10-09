-- luacheck: ignore
return [[
<html>

<head>
    <title>协议测试</title>
    <style type="text/css">
    </style>
    <link id="custom-css" rel="stylesheet" type="text/css" />
    <meta charset="utf-8">
    <script src="https://cdnjs.cloudflare.com/ajax/libs/angular.js/1.8.3/angular.min.js"></script>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/downloadjs/1.4.8/download.min.js"></script>
</head>

<body>
    <div ng-app="robot" ng-controller="protocol">
        <div class="left-half">
            <div class="show-stage-area pipeline-stage">
                <button type="button" class="bk-button-normal bk-button pipeline-stage-entry light-gray"
                    ng-click="caseShow=true">
                    <div class="center-box">
                        <div class="stage-content">{{curCaseName}}</div>
                    </div>
                </button>
                <div class="left-pad">
                    <p>服务器地址: {{serverAddr}}</p>
                    <p>OpenID: {{openid}}</p>
                    <p>roleId: {{roleId}}<button id="runall-btn" class="edit-btn" ng-show="roleId"
                            ng-click="copyRoleId()">{{copyRoleTip}}</button></p>
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
                        <span class="add-atom-entry" ng-show="isShowCaseNew()"><i class="add-plus-icon"
                                ng-click="addItem(cmd)"></i></span>
                        <section style="overflow-y: auto;height:250">
                            <div class="container-atom-list" ng-repeat="cmd in curProtocolSort" id="case_protocols">
                                <li class="atom-item">
                                    <section class="atom-item atom-section normal-atom">
                                        <svg width="18" height="18" viewBox="0 0 32 32" class="atom-icon"
                                            ng-click="showProtocol(false, cmd)">
                                            <path
                                                d="M25.82 4H23c0-1.1-.98-2-2.2-2h-.2c0-1.1-.98-2-2.2-2h-4.8c-1.22 0-2.2.9-2.2 2h-.2C9.98 2 9 2.9 9 4H6.18C4.42 4 3 5.34 3 7v22c0 1.66 1.42 3 3.18 3h19.64c1.76 0 3.18-1.34 3.18-3V7c0-1.66-1.42-3-3.18-3zM11.2 4h1.2c.56 0 1-.44 1-1l-.02-.92c.02-.02.08-.08.22-.08h4.8c.12 0 .2.04.2.02V3c0 .56.44 1 1 1h1.2c.12 0 .2.04.2.02v1l.02 2.9c-.02.02-.08.08-.22.08h-9.6c-.08 0-.16-.02-.18-.02S11 7.98 11 8l-.02-2.94c0-.02.02-.04.02-.06s-.02-.04-.02-.08v-.86c.02 0 .08-.06.22-.06zM27 29c0 .56-.52 1-1.18 1H6.18C5.52 30 5 29.56 5 29V7c0-.56.54-1 1.18-1H9v2c0 1.1.98 2 2.2 2h9.6c1.22 0 2.2-.9 2.2-2V6h2.82c.66 0 1.18.44 1.18 1v22z">
                                            </path>
                                            <path
                                                d="M22 16H10c-.56 0-1 .44-1 1s.44 1 1 1h12c.56 0 1-.44 1-1s-.44-1-1-1zM22 20H10c-.56 0-1 .44-1 1s.44 1 1 1h12c.56 0 1-.44 1-1s-.44-1-1-1zM22 24H10c-.56 0-1 .44-1 1s.44 1 1 1h12c.56 0 1-.44 1-1s-.44-1-1-1z">
                                            </path>
                                        </svg>
                                        <p class="atom-name" ng-click="showProtocol(false, cmd)">
                                            <span>{{cmd.name}}</span>
                                        </p>
                                        <i class="add-plus-icon close run" ng-click="runProtocol(cmd)"></i>
                                        <i class="add-plus-icon close" ng-click="removeItem(cmd)"></i>
                                    </section>
                                </li>
                                <span class="add-atom-entry"><i class="add-plus-icon"
                                        ng-click="addItem(cmd)"></i></span>
                            </div>
                        </section>
                        <h3 class="container-title first-ctitle">
                            <span id="stop-btn" class="stage-status container" ng-click="stopRobot()">停止</span>
                            <p class="container-name" ng-click="stopRobot()"><span id="stop-text">停止Robot</span></p>
                        </h3>
                    </div>
                </ul>
                <button id="runall-btn" class="add-plus-icon login-button run-button" ng-click="runAll()">Run
                    All</button><br>
                <button id="runall-btn" class="add-plus-icon login-button run-button"
                    ng-click="msgFilterShow=true">消息筛选</button><br>
                <button id="runall-btn" class="add-plus-icon login-button run-button"
                    ng-click="cleanLogs()">清空控制台</button>
            </div>
        </div>
        <div class="checkbox">
            <label class="checkbox-inline">
                <input type="checkbox" ng-model="topCheckbox.msgFilter" ng-change="onCheckboxChange('msgFilter')">消息筛选
            </label>
            <label class="checkbox-inline">
                <input type="checkbox" ng-model="topCheckbox.rptAtt" ng-change="onCheckboxChange('rptAtt')">回执关注
            </label>
            <label class="checkbox-inline">
                <input type="checkbox" ng-model="topCheckbox.login" ng-change="onCheckboxChange('login')">登录关注
            </label>
            <label class="checkbox-inline">
                <input type="checkbox" ng-model="topCheckbox.all" ng-change="onCheckboxChange('all')">显示所有
            </label>
            <label class="checkbox-inline">
                <input type="checkbox" class="checke" style="margin-right: 50px;float: right;"
                    ng-model="topCheckbox.msgRoll">
            </label>
        </div>
        <div id="dg" style="z-index: 9999; position: fixed ! important; right: 0px; bottom: 5%;">
            <table width="" 100% style="position: absolute; width:260px; right: 0px; bottom: 0px;">
                <button class="log-fast-btn" style="margin-bottom: 10px;" ng-click="gotoLogTop()">
                    <span style="color: white;">回到顶部</span>
                </button><br>
                <button class="log-fast-btn" style="margin-bottom: 10px;" ng-click="gotoLogBottom()">
                    <span style="color: white;">回到底部</span>
                </button>
            </table>
        </div>
        <div class="log-half" id="message_content" scroll="log-half">
            <pre id="jsonShow">  {{messages}}</pre>
        </div>
        <article id="side-protocol" class="bk-sideslider bkci-property-panel" style="z-index: 2021;"
            ng-show="protoShow">
            <section class="bk-sideslider-wrapper right" style="width: 600px;">
                <div class="bk-sideslider-header">
                    <i class="bk-sideslider-closer" style="float: left;" ng-click="showProtocol(false)">
                        <i class="bk-icon icon-angle-right"></i>
                    </i>
                    <div class="bk-sideslider-title" style="padding: 0px 0px 0px 50px;">
                        <header class="property-panel-header">
                            <div>
                                <p>{{curProtocol ? curProtocol.name : ""}}</p>
                            </div>
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

                                            <label class="bk-label atom-form-label">协议分组:</label>
                                            <select class="bk-form-input" ng-model="accordGroupIndex" ng-change="changeAccordGroup()"
                                                ng-options="key as value.name for (key, value) in accordGroupSort"></select>

                                            <label class="bk-label atom-form-label">协议选项:</label>
                                            <select id="protocolSelectIndex" class="bk-form-input" ng-model="protocolSelectIndex"
                                                ng-change="changeAccordSelect()"
                                                ng-options="key as value.name for (key, value) in accordSelectSort"></select>


                                            <label class="bk-label atom-form-label">协议名称:</label>
                                            <input type="text" class="bk-form-input"
                                                ng-model="curProtocol.name"></input>
                                            <label class="bk-label atom-form-label">协议ID:</label>
                                            <input type="number" class="bk-form-input"
                                                ng-model="curProtocol.cmd_id"></input>
                                            <label class="bk-label atom-form-label">协议参数(json格式)：</label>
                                            <div class="bk-form-content">
                                                <textarea ng-model="curProtocol.args"
                                                    class="input-textarea">{{curProtocol.args}}</textarea>
                                            </div><br>
                                            <div>
                                                回执关注(默认关注RES协议)(示例:1000,1001):<input type="text" class="bk-form-input"
                                                    ng-model="curProtocolRptAtt"></input>
                                            </div><br>
                                            <div class="center-box">
                                                <button class="add-plus-icon login-button" ng-click="insertProtoData()"
                                                    ng-hide="protoeNew">保存</button>
                                                <button class="add-plus-icon login-button" ng-click="insertProtoData()"
                                                    ng-show="protoeNew">确定</button>
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

        <!--消息筛选-->
        <article class="bk-sideslider bkci-property-panel" style="z-index: 2021;" ng-show="msgFilterShow">
            <section class="bk-sideslider-wrapper right" style="width: 600px;">
                <div class="bk-sideslider-header">
                    <i class="bk-sideslider-closer" style="float: left;" ng-click="msgFilterShow=false">
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
                                            <label
                                                class="bk-label atom-form-label">消息筛选(格式:逗号分割)(例如:10000,10001)</label>
                                            <div class="bk-form-content">
                                                <textarea id="parameter" name="parameter" ng-model="msgFilterText"
                                                    class="input-textarea">{{msgFilterText}}</textarea>
                                            </div><br>
                                            <div class="center-box">
                                                <button class="add-plus-icon login-button" ng-click="upProtFilter()"
                                                    ng-hide="protoNew">保存</button>
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

        <!--用例分组-->
        <article class="bk-sideslider bkci-property-panel" style="z-index: 2021;" ng-show="caseGroupShow">
            <section class="bk-sideslider-wrapper right" style="width: 600px;">
                <div class="bk-sideslider-header">
                    <i class="bk-sideslider-closer" style="float: left;" ng-click="showCaseGroup(false)">
                        <i class="bk-icon icon-angle-right"></i>
                    </i>
                </div>
                <div class="bk-sideslider-content" style="max-height: calc(100vh - 30px); position: relative;">
                    <div class="center-box">
                        <button class="add-plus-icon login-button" ng-click="showCaseGroupEdit(true)"
                            ng-hide="protoNew">添加分组</button>
                    </div>
                    <section class="atom-property-panel">
                        <div class="atom-main-content" style="position: relative;">
                            <div class="atom-form-content">
                                <div class="atom-form-box">
                                    <section class="bk-form bk-form-vertical atom-content" atom="[object Object]">
                                        <div class="form-field bk-form-item is-required">
                                            <ul ng-repeat="group in caseGroupMap">
                                                <li class="srv-li">
                                                    {{ group.name }}
                                                    <button class="edit-btn" ng-click="editCaseGroup(group)">编辑</button>
                                                    <button class="del-btn" ng-click="delCaseGroup(group)">删除</button>
                                                </li>
                                            </ul>
                                        </div>
                                    </section>
                                </div>
                            </div>
                        </div>
                    </section>
                </div>
            </section>
        </article>


        <!--编辑/添加分组-->
        <article class="bk-sideslider bkci-property-panel" style="z-index: 2021;" ng-show="caseGroupEditShow">
            <section class="bk-sideslider-wrapper right" style="width: 600px;">
                <div class="bk-sideslider-header">
                    <i class="bk-sideslider-closer" style="float: left;" ng-click="showCaseGroupEdit(false)">
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
                                            <div class="atom-form-box">
                                                <label class="bk-label atom-form-label">分组名称:</label>
                                                <input type="text" class="bk-form-input"
                                                    ng-model="caseGroupEditItem.name"></input>
                                            </div><br>
                                            <div class="center-box" style="width: 100%;height: 80px;">
                                                <button class="add-plus-icon login-button" ng-click="saveCaseGroup()"
                                                    ng-hide="protoNew">保存</button>
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
                            <div>
                                <p>配置测试用例</p>
                            </div>
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
                                        <label class="bk-label atom-form-label">选择用例分组:</label>
                                        <button id="runall-btn" class="edit-btn"
                                            ng-click="showCaseGroup(true)">编辑</button><br>
                                        <select class="bk-form-input" ng-model="caseGroupName"
                                            ng-change="changeCaseGroup()"
                                            ng-options="x for x in caseGroupSort"></select>
                                        <label ng-show="caseNew || caseEdit"
                                            class="bk-label atom-form-label">输入用例名称:</label>
                                        <input ng-show="caseNew || caseEdit" type="text" class="bk-form-input"
                                            ng-model="curCaseName"></input>
                                        <label ng-show="!caseNew && !caseEdit"
                                            class="bk-label atom-form-label">选择测试用例:</label>
                                        <select ng-show="!caseNew && !caseEdit" class="bk-form-input"
                                            ng-model="curCaseIndex"
                                            ng-options="key as value.name for (key, value) in accordsListFiltr"
                                            ng-change="changeCases()"></select>


                                        <label class="bk-label atom-form-label">选择服务器:</label>
                                        <select class="bk-form-input" ng-model="serverAddr"
                                            ng-options="x for x in serverSort"></select>
                                        <label class="bk-label atom-form-label">输入OPENID:</label>
                                        <input type="text" class="bk-form-input" ng-model="openid"></input>
                                        <label class="bk-label atom-form-label">输入密码:</label>
                                        <input type="text" class="bk-form-input" ng-model="passwd"></input>
                                        <label class="bk-label atom-form-label">回执关注(示例:1000,1001):</label>
                                        <input type="text" class="bk-form-input" ng-model="caseRptAtt"></input>
                                        <div class="center-box" style="width: 100%;height: 80px;">
                                            <button class="add-plus-icon login-button" ng-click="saveCase(false)"
                                                ng-hide="caseNew">保存</button>
                                            <button class="add-plus-icon login-button" ng-click="insertCase()"
                                                ng-show="caseNew">添加</button>
                                        </div>
                                        <div class="center-box" style="width: 100%;height: 80px;" ng-show="caseEdit">
                                            <button class="add-plus-icon login-button"
                                                ng-click="saveCase(true)">克隆</button>
                                        </div>
                                        <div class="center-box" style="width: 100%;height: 80px;" ng-show="caseEdit">
                                            <button class="login-button" ng-click="caseEdit=false">取消</button>
                                        </div>
                                        <div class="center-box" style="width: 100%;height: 80px;">
                                            <button class="add-plus-icon login-button" ng-click="caseEdit=true"
                                                ng-show="!caseEdit&&!caseNew">编辑</button>
                                        </div>
                                        <div class="center-box" style="width: 100%;height: 80px;">
                                            <button class="login-button del-btn" ng-click="deleteCase()"
                                                ng-show="showDeleteCase()">删除</button>
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
    //全局uuid自增
var g_uuid_index = 0;
var DataUtils = {
    //获取当前时间戳(毫秒)
    getNowTime:function(){
        return Date.now();
    },
    //获取当前时间戳(毫秒)
    getNowMilliSecond:function(){
        return Date.now();
    },
    //获取当前时间戳(秒)
    getNowSecond:function(){
        var result = Math.floor(this.getNowTime() / 1000);
	    return result;
    },
    //深拷贝
    deepCopy:function (source) {
        var sourceCopy = null;
        if (source instanceof Array) {
            sourceCopy = [];
        }
        else {
            if (source) {
                sourceCopy = {};
            }
            else {
                sourceCopy = source;
            }
        }

        for (var item in source) {
            if (typeof source[item] === 'object') {
                sourceCopy[item] = this.deepCopy(source[item]);
            }
            else {
                sourceCopy[item] = source[item];
            }
        }
        return sourceCopy;
    },
    generateUUID:function(maxCount=10000){
        var uuid = "" + Date.now() + g_uuid_index;
        g_uuid_index++;
        if (g_uuid_index >= maxCount) {
            //一毫米内超过maxCount个uuid有问题
            g_uuid_index = 0;
        }
        return uuid;
    },
    getMapCount:function(map){
        var count = 0
        for (var key in map) {
            count++
        }
        return count
    },
    isValidIP:function(address){
        const ipPattern = /^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$/;
        return ipPattern.test(address);
    },
    copyToClipboard:function(str){
        if (navigator.clipboard && window.isSecureContext) {
            return navigator.clipboard.writeText(str);
        } else {
            let textArea = document.createElement("textarea");
            textArea.value = str;
            textArea.style.position = "absolute";
            textArea.style.opacity = 0;
            textArea.style.left = "-999999px";
            textArea.style.top = "-999999px";
            document.body.appendChild(textArea);
            textArea.focus();
            textArea.select();
            return new Promise((res, rej) => {
                document.execCommand('copy') ? res() : rej();
                textArea.remove();
            });
        }
    },
    arrObjIndexOf(array, key, val){
        for(var i=0; i<array.length; i++){
            var item = array[i]
            if(item[key] == val){
                return i
            }
        }
        return null
    }
}
    var FormatUtils = {
    prettyFormat:function(str){
        try {
            // 去除JSON.stringify带来的hashkey
            str.$$hashKey = undefined
            if (typeof (str) != "string") {
                // 设置缩进为2个空格
                str = JSON.stringify(str, null, 2);
            }
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
    },
    formatJson:function(text){
        var result = text.replace(/\\n/g, '\n').replace(/\\/g, '').replace(/^\"|\"$/g, '');
        return result
    },
}
    var NetUtils = {
    http: null,
    init: function(http){
        this.http = http
    },
    post: function (name, args, callback) {
        this.http.post(name, args).then(function (response) {
            var data = response.data || {}
            if(response.status == 200){
                if(callback){
                    callback(true, data)
                }
            }else {
                callback(false, data)
                console.error("[Request][post] fail name(%s) args(%s) status(%s)", name, args, response.status)
            }
        }, function (response) {
            callback(false, null)
            console.error("[Request][post] fail name(%s) args(%s) status(%s)", name, args, response.status)
        });
    },
    get: function(name, args, callback){
        this.http.get(name, args).then(function(response){
            var data = response.data || {}
            if(response.status == 200){
                if(callback){
                    callback(true, data)
                }
            }else {
                callback(false, data)
                console.error("[Request][get] fail name(%s) args(%s) status(%s)", name, args, response.status)
            }
        }, function (response) {
            callback(false, null)
            console.error("[Request][get] fail name(%s) args(%s) status(%s)", name, args, response.status)
        });
    }
}

    var scope = null
    var http = null
    var app = angular.module('robot', [])
    app.directive('scroll', function () {
        return {
            restrict: 'A',
            link: function (scope, element, attrs) {
                scrollName = attrs.scroll;
                element.bind('mousedown', function (event) {
                    if (scrollName == "log-half") {
                        scope.topCheckbox.msgRoll = false
                    }
                })
            }
        };
    })
    app.controller('protocol', function ($scope, $http, $interval) {
        scope = $scope
        http = $http
        NetUtils.init(http)
        //////////////////////////////////////////////////////////////////
        //账号信息
        $scope.openid = null            //账号
        $scope.passwd = null            //密码
        $scope.roleId = 0               //角色id
        $scope.logined = false          //登录状态(false 未登录 true 登录成功)

        //////////////////////////////////////////////////////////////////
        //服务信息
        $scope.serverAddr = null        //服务器地址
        $scope.robotStatus = "未启动"   //机器状态
        $scope.srvListApi = ""          //服务列表api
        $scope.serverList = {}          //服务列表
        $scope.serverSort = []          //服务列表排序
        $scope.serverEdit = null        //编辑服务

        //////////////////////////////////////////////////////////////////
        //测试用例
        $scope.caseShow = false         //测试用例弹框
        $scope.caseNew = false          //用例新加标记
        $scope.caseEdit = false         //用例编辑标记
        $scope.caseRptAtt = ""          //用例的回执关注
        $scope.caseGroupShow = false    //用例分组弹框
        $scope.caseGroupEditShow = false//用例分组编辑弹框
        $scope.caseGroupEditItem = null //用例分组编辑对象
        $scope.caseGroupName = ""       //当前选择的分组名称
        $scope.caseGroupMap = {}        //用例分组映射
        $scope.caseGroupSort = []       //用例分组排序
        $scope.curCaseIndex = null      //当前选择的用例下标
        $scope.curCase = null           //当前选择的用例对象
        $scope.curCaseName = "请选择测试用例"   //当前选择的用例名称

        //////////////////////////////////////////////////////////////////
        //协议相关
        $scope.protoShow = false        //协议配置弹框
        $scope.protoNew = false         //新的协议
        $scope.accordGroupMap = {}      //协议分组映射(根据pb文件生成)
        $scope.accordGroupSort = []     //协议分组排序
        $scope.accordSelectSort = []    //协议选项排序
        $scope.accordCmdMap = {}        //协议列表(协议号映射)
        $scope.accordsList = {}         //协议列表
        $scope.accordsListFiltr = []    //协议列表(根据选择的分组过滤)
        $scope.curProtocols = null      //当前的协议列表
        $scope.curProtocolSort = []     //当前的协议排序
        $scope.curProtocol = null       //当前选中的协议
        $scope.curProtocolRptAtt = ""   //当前选中协议的回执关注
        $scope.accordGroupIndex = "0"     //协议分组下标
        $scope.protocolSelectIndex = "0"  //协议选项下标
        $scope.curProtocolGroup = null  //协议分组
        $scope.curProtocolSelect = null //协议选项列表

        //////////////////////////////////////////////////////////////////
        //ui控制
        $scope.topCheckbox = {
            msgFilter: true,            //消息过滤
            rptAtt: true,               //回执关注
            msgRoll: true,              //登录关注
            login: true,                //消息滚动
            all: false,                 //显示所有
        }
        $scope.copyRoleTip = "复制"
        $scope.copyRoleTime = null

        //////////////////////////////////////////////////////////////////
        //消息过滤
        $scope.msgFilterShow = false    //消息过滤弹框
        $scope.msgFilterText = ""       //消息过滤绑定变量
        $scope.msgFilters = {}          //消息过滤列表

        //////////////////////////////////////////////////////////////////
        //日志输出
        $scope.messages = ""

        //////////////////////////////////////////////////////////////////
        //逻辑相关
        $scope.queueReqList = []        //执行队列
        $scope.showOperator = false     //左侧操作列

        //初始化数据
        $scope.loadData = function () {
            NetUtils.post("/accord_group", {}, function (ok, data) {
                if (!ok) {
                    return
                }
                for(var i in data.accord_group || {}){
                    if(!$scope.accordGroupMap[i]){
                        $scope.accordGroupMap[i] = {}
                    }
                    var group = data.accord_group[i]
                    for(var j in group || {}){
                        var accord = group[j]
                        if(accord.type != 'req'){
                            continue
                        }
                        if(!$scope.accordGroupMap[i][j]){
                            $scope.accordGroupMap[i][j] = accord
                        }
                    }
                }
                $scope.refreshServer()
                $scope.refreshAccordGroup()
            })
            NetUtils.post("/case_group", {}, function (ok, data) {
                if (!ok) {
                    return
                }
                $scope.caseGroupMap = data.case_group
                $scope.refreshCaseGroup()
            })

            NetUtils.post("/get_config", {}, function (ok, data) {
                if (!ok) {
                    return
                }
                $scope.srvListApi = data.srvlist_api
                console.log("srvListApi=%s", $scope.srvListApi)
                NetUtils.get($scope.srvListApi, {}, function (ok, data) {
                    if (!ok) {
                        return
                    }
                    for(var i=0; i<data.data.length; i++){
                        var item = data.data[i]
                        var address = item.address.split(':');
                        console.log("address=%s",JSON.stringify(address))
                        $scope.serverList[item.id] = {
                            id:item.id,
                            name: item.name,
                            address: address[0],
                            port: address[1],
                            time: 0,
                        }
                    }
                    $scope.refreshServer()
                })
            })

            
            NetUtils.post("/accord_list", {}, function (ok, data) {
                if (!ok) {
                    return
                }
                $scope.accordsList = data.accord_list
                for (var key in data.accord_list) {
                    var accord = data.accord_list[key]
                    if (accord) {
                        $scope.accordsList[key] = {}
                        var newAccord = $scope.accordsList[key]
                        newAccord.id = key
                        newAccord.name = accord.name
                        newAccord.openid = accord.openid
                        newAccord.passwd = accord.passwd
                        newAccord.server = accord.server
                        newAccord.casegroup = accord.casegroup
                        newAccord.rpt_att = []
                        newAccord.protocols = {}
                        //回执关注
                        for (var rpt_key in accord.rpt_att) {
                            var rpt = accord.rpt_att[rpt_key]
                            newAccord.rpt_att.push(rpt)
                        }
                        //协议数据
                        for (var id in accord.protocols) {
                            var proto = accord.protocols[id]
                            newAccord.protocols[id] = {}
                            var newProto = newAccord.protocols[id]
                            newProto.id = proto.id
                            newProto.name = proto.name
                            newProto.cmd_id = proto.cmd_id
                            newProto.time = proto.time
                            newProto.args = proto.args
                            newProto.rpt_att = []
                            //回执关注
                            for (var rpt_key in proto.rpt_att) {
                                var rpt = proto.rpt_att[rpt_key]
                                newProto.rpt_att.push(rpt)
                            }
                        }
                    }
                }
            })
        }
        scope.loadData()
        //设置当前协议
        $scope.setCurProtocols = function (val) {
            $scope.curProtocols = val
            $scope.upCurProtocolArr()
        }
        //更新协议数组
        $scope.upCurProtocolArr = function () {
            $scope.curProtocolSort = []
            if ($scope.curProtocols) {
                for (var key in $scope.curProtocols) {
                    var proto = $scope.curProtocols[key]
                    $scope.curProtocolSort.push(proto)
                }
                $scope.curProtocolSort.sort(function (a, b) {
                    return a.time - b.time
                })
            }
        }
        //是否显示新建标记
        $scope.isShowCaseNew = function () {
            if ($scope.caseNew) {
                return true
            }
            if ($scope.curCase && DataUtils.getMapCount($scope.curCase.protocols) == 0) {
                return true
            }
            return false
        }
        //定时器
        $interval(function () {
            if ($scope.logined) {
                //处理滚动条
                if ($scope.topCheckbox.msgRoll) {
                    var divscll = document.getElementById('message_content');
                    divscll.scrollTop = divscll.scrollHeight;
                }
                //发送心跳
                $scope.runHeartBeat()
                //获取服务器推送消息
                NetUtils.get("message", { params: { "open_id": $scope.openid } }, function (ok, data) {
                    if (!ok) {
                        return
                    }
                    var append = true
                    if (data.msg && Object.keys(data.msg).length != 0) {
                        var msg = data.msg
                        var cmd_id = msg.cmd_id;
                        if ($scope.topCheckbox.msgFilter && !$scope.msgFilters[cmd_id]) {
                            append = false
                        }

                        //登录回执关注(cmd_id千分位=0表示登录服务的协议号)
                        if (!append && $scope.topCheckbox.login) {
                            if (parseInt((msg.cmd_id / 1000) % 10) == 0 || msg.cmd_id <= 10019) {
                                append = true
                            }
                        }

                        if (append || $scope.topCheckbox.all) {
                            $scope.messages += "\n\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]服务器通知:\n" + FormatUtils.prettyFormat(data)
                            document.getElementById('jsonShow').innerHTML = $scope.messages
                        }

                        //更新roleid
                        if (msg.cmd_id == 10002) {
                            if (msg.roles && msg.roles.length > 0) {
                                $scope.roleId = msg.roles[0].role_id
                            }
                        }
                    }
                })
            }
        }, 1000 * 1);
        //成员函数
        $scope.showProtocol = function (isNew, cmd) {
            $scope.protoNew = isNew
            $scope.protoShow = cmd ? true : false;
            if (cmd && cmd.id) {
                $scope.curProtocol = DataUtils.deepCopy(cmd)
                $scope.curProtocolRptAtt = cmd.rpt_att.join(",")
                //读取配置
                var item = $scope.accordCmdMap[cmd.cmd_id]
                if (item) {
                    var groupIndex = DataUtils.arrObjIndexOf($scope.accordGroupSort, "name", item.name)
                    $scope.accordGroupIndex = groupIndex != null ? groupIndex.toString() : "-1"
                    $scope.changeAccordGroup()
                    var protocolIndex = DataUtils.arrObjIndexOf($scope.accordSelectSort, "msg_id", cmd.cmd_id)
                    $scope.protocolSelectIndex = protocolIndex != null ? protocolIndex.toString() : "-1"
                    $scope.curProtocolGroup = item.group
                    $scope.curProtocolSelect = item.select
                }
            } else {
                if (!$scope.protoShow) {
                    $scope.curProtocolSelect = null
                    $scope.protocolSelectIndex = -1
                }
            }
        }
        //显示用例分组
        $scope.showCaseGroup = function (value) {
            if (value) {
                $scope.caseShow = false
            } else {
                $scope.caseShow = true
            }
            $scope.caseGroupShow = value
        }
        //显示添加/编辑框
        $scope.showCaseGroupEdit = function (value, back) {
            $scope.caseGroupEditShow = value
            if (back) {
                this.showCaseGroup(true)
            }
            if (value) {
                $scope.caseGroupEditItem = {
                    id: DataUtils.generateUUID(),
                    name: "",
                    time: DataUtils.getNowSecond()
                }
            }
        }
        //刷新分组
        $scope.refreshAccordGroup = function () {
            //映射
            $scope.accordCmdMap = {}
            for (var group_key in $scope.accordGroupMap) {
                var group = $scope.accordGroupMap[group_key]
                for (var item_key in group) {
                    var item = group[item_key]
                    $scope.accordCmdMap[item.msg_id] = {
                        name: group_key,
                        group: group,
                        select: item
                    }
                }
            }

            $scope.accordGroupSort = []
            var groupSort = []
            for (var group_key in $scope.accordGroupMap) {
                var group = $scope.accordGroupMap[group_key]
                for (var item_key in group) {
                    var item = group[item_key]
                    $scope.accordGroupSort.push({
                        name: group_key,
                        group:group,
                        msg_id: item.msg_id
                    })
                    break;
                }
            }
            $scope.accordGroupSort.sort(function(a,b){
                return a.msg_id - b.msg_id
            })
            $scope.changeAccordGroup()
        }
        //刷新用例分组
        $scope.refreshCaseGroup = function () {
            var caseGroupSort = []
            $scope.caseGroupSort = []
            for (var key in $scope.caseGroupMap) {
                var group = $scope.caseGroupMap[key]
                caseGroupSort.push(group)
            }
            caseGroupSort.sort(function (a, b) {
                return a.time - b.time
            })
            for (var key in caseGroupSort) {
                var group = caseGroupSort[key]
                $scope.caseGroupSort.push(group.name)
            }
            //添加默认协议分组
            for (var i=0; i<$scope.accordGroupSort.length; i++) {
                var item = $scope.accordGroupSort[i]
                $scope.caseGroupSort.push(item.name)
            }
        }
        //保存分组
        $scope.saveCaseGroup = function () {
            if (!$scope.caseGroupEditItem) {
                alert("名称不能为空");
                return
            }

            //重复验证
            for (var key in $scope.caseGroupMap) {
                var group = $scope.caseGroupMap[key]
                if (group.name == $scope.caseGroupEditItem.name) {
                    $scope.showCaseGroupEdit(false, true)
                    return
                }
            }

            NetUtils.post("/case_group_edit", {
                "data": {
                    case_group: $scope.caseGroupEditItem
                }
            }, function (ok, data) {
                if (!ok) {
                    alert("保存失败!")
                    return
                }
                $scope.caseGroupMap[$scope.caseGroupEditItem.id] = $scope.caseGroupEditItem
                $scope.showCaseGroupEdit(false, true)
                $scope.refreshCaseGroup()
            })

        }
        //编辑分组
        $scope.editCaseGroup = function (group) {
            console.log("editCaseGroup group(%s)", group)
            this.showCaseGroupEdit(true)
            //拷贝配置
            $scope.caseGroupEditItem = group
        }
        //删除分组
        $scope.delCaseGroup = function (group) {
            var result = $scope.getAccordGroupCount(group.name)
            if(result.accord_count>0){
                var ok = window.confirm(`该分组中,存在[${result.accord_count}]条用例,[${result.protocol_count}]条协议配置],您确定要删除吗?`);
                if(!ok){
                    return
                }
            }
            NetUtils.post("/case_group_del", {
                "data": group
            }, function (ok, data) {
                if (!ok) {
                    alert("删除失败")
                    return
                }
                delete $scope.caseGroupMap[group.id]
                $scope.clearAccordByGroup(group.name)
                $scope.showCaseGroupEdit(false, true)
                $scope.refreshCaseGroup()
            })
        }
        //刷新服务
        $scope.refreshServer = function () {
            $scope.serverSort = []
            for (var key in $scope.serverList) {
                var server = $scope.serverList[key]
                var name = server.name + "(" + server.address + ":" + server.port + ")"
                $scope.serverSort.push(name)
            }
            $scope.serverSort.sort(function (a, b) {
                return a.time - b.time
            })
        }
        $scope.showCase = function (isShow) {
            $scope.caseShow = isShow
            if (!isShow && $scope.logined) {
                //暂停机器人
                $scope.stopRobot()
            }
        }
        //保存数据
        $scope.saveCase = function (clone) {
            //配置验证
            if (!$scope.curCaseName) {
                alert("请输入用例名称!")
                return
            }

            if (!$scope.openid) {
                alert("请输入OPENID!")
                return
            }

            if (!$scope.passwd) {
                alert("请输入密码!")
                return
            }

            //回执关注
            var rptAtt = []
            if ($scope.caseRptAtt) {
                var array = $scope.caseRptAtt.split(",")
                for (var i = 0; i < array.length; i++) {
                    var val = parseInt(array[i])
                    if (val) {
                        rptAtt.push(val)
                    }
                }
            }

            //重复验证
            if (clone && $scope.getAccordByName($scope.caseGroupName, $scope.curCaseName)) {
                alert("分组中存在相同名称的测试用例,请更换名称,完成克隆!")
                return
            }

            accord = $scope.accordsList[$scope.curCase.id]
            if (!accord) {
                accord = {
                    id: DataUtils.generateUUID(),
                    name: $scope.curCaseName,
                    openid: $scope.openid,
                    passwd: $scope.passwd,
                    server: $scope.serverAddr,
                    rpt_att: rptAtt,
                    casegroup: $scope.caseGroupName,
                    protocols: {},
                    time: DataUtils.getNowSecond()
                }
            } else {
                accord = clone ? DataUtils.deepCopy(accord) : accord
                accord.name = $scope.curCaseName
                accord.openid = $scope.openid
                accord.passwd = $scope.passwd
                accord.server = $scope.serverAddr
                accord.casegroup = $scope.caseGroupName
                accord.rpt_att = rptAtt
                accord.time = DataUtils.getNowSecond()
            }

            if (clone) {
                accord.id = DataUtils.generateUUID()
            }

            NetUtils.post("/accord_edit", {
                "data": {
                    id: accord.id,
                    name: accord.name,
                    openid: accord.openid,
                    passwd: accord.passwd,
                    server: accord.server,
                    rpt_att: accord.rpt_att,
                    casegroup: accord.casegroup,
                    protocols: clone ? accord.protocols : null,
                    time: accord.time,
                }
            }, function (ok, data) {
                if (!ok) {
                    alert("保存失败")
                    return
                }
                $scope.accordsList[accord.id] = accord
                $scope.upProtFilter()
                $scope.showCase(false)
                $scope.caseEdit = false
                $scope.caseNew = false
                $scope.curCase = accord
                $scope.refreshAccordListFiltr()
                $scope.curCaseIndex = ($scope.accordsListFiltr.length - 1).toString()
            })
        }
        //添加测试用例
        $scope.insertCase = function () {
            //配置验证
            if (!$scope.curCaseName) {
                alert("请输入用例名称!")
                return
            }

            if (!$scope.caseGroupName) {
                alert("请选择用例分组!")
                return
            }

            if (!$scope.serverAddr) {
                alert("请选择服务器!")
                return
            }

            if (!$scope.openid) {
                alert("请输入OPENID!")
                return
            }

            if (!$scope.passwd) {
                alert("请输入密码!")
                return
            }

            if ($scope.getAccordByName($scope.caseGroupName, $scope.curCaseName)) {
                alert("测试用例已存在!")
                return
            }

            //回执关注
            var rptAtt = []
            if ($scope.caseRptAtt) {
                var array = $scope.caseRptAtt.split(",")
                for (var i = 0; i < array.length; i++) {
                    var val = parseInt(array[i])
                    if (val) {
                        rptAtt.push(val)
                    }
                }
            }

            //构建数据结构
            var accord = {
                id: DataUtils.generateUUID(),
                name: $scope.curCaseName,
                openid: $scope.openid,
                passwd: $scope.passwd,
                server: $scope.serverAddr,
                rpt_att: rptAtt,
                casegroup: $scope.caseGroupName,
                protocols: {},
                time: DataUtils.getNowSecond()
            }

            NetUtils.post("/accord_edit", {
                "data": {
                    id: accord.id,
                    name: accord.name,
                    openid: accord.openid,
                    passwd: accord.passwd,
                    server: accord.server,
                    rpt_att: accord.rpt_att,
                    casegroup: accord.casegroup,
                    time: accord.time,
                }
            }, function (ok, data) {
                if (!ok) {
                    alert("添加失败")
                    return
                }
                $scope.accordsList[accord.id] = accord
                $scope.curCase = accord
                $scope.setCurProtocols(accord.protocols)
                $scope.showCase(false)
                $scope.caseEdit = false
                $scope.caseNew = false
                $scope.refreshAccordListFiltr()
                $scope.curCaseIndex = ($scope.accordsListFiltr.length - 1).toString()
                alert("添加成功!")
            })
            $scope.showOperator = true
        }
        //是否显示删除按钮
        $scope.showDeleteCase = function () {
            if (!$scope.caseNew && $scope.curCase && !$scope.caseEdit) {
                return true
            }
            return false
        }
        //是否显示编辑按钮
        $scope.showEditCase = function () {
            if (!$scope.caseNew && $scope.curCase) {
                return true
            }
            return false
        }
        //删除测试用例
        $scope.deleteCase = function () {
            if (!$scope.curCase) {
                return
            }
            NetUtils.post("/accord_del", {
                "data": {
                    id: $scope.curCase.id
                }
            }, function (ok, data) {
                if (!ok) {
                    alert("删除失败")
                    return
                }
                delete $scope.accordsList[$scope.curCase.id]
                $scope.refreshAccordListFiltr()
                $scope.newCase()
                alert("删除成功!")
            })
        }
        //刷新消息过滤
        $scope.upProtFilter = function () {
            $scope.msgFilters = {}
            var id_logs = []
            //协议过滤的数据
            if ($scope.topCheckbox.msgFilter) {
                var cmds = $scope.msgFilterText.split(",")
                for (var i = 0; i < cmds.length; i++) {
                    var cmd_id_s = cmds[i].split("-")
                    if (cmd_id_s.length <= 2) {
                        if (cmd_id_s.length == 1) {
                            var cmd_id = parseInt(cmd_id_s[0])
                            if (cmd_id) {
                                $scope.msgFilters[cmd_id] = cmd_id;
                                id_logs.push(cmd_id)
                            }
                        } else {
                            var s_cmd_id = parseInt(cmd_id_s[0])
                            var e_cmd_id = parseInt(cmd_id_s[1])
                            for (var id = s_cmd_id; id <= e_cmd_id; id++) {
                                $scope.msgFilters[id] = id;
                                id_logs.push(cmd_id)
                            }
                        }
                    }
                }
            }

            //回执关注的数据
            if ($scope.topCheckbox.rptAtt) {
                //添加用例中的回执关注
                for(var i=0; i<$scope.curCase.rpt_att.length; i++){
                    var id = $scope.curCase.rpt_att[i]
                    $scope.msgFilters[id] = id
                }
                id_logs = id_logs.concat($scope.curCase.rpt_att)
                //默认关注所有协议的res
                if($scope.curProtocols){
                    for (var key in $scope.curProtocols) {
                        var item = $scope.curProtocols[key]
                        if (!item) {
                            continue
                        }
                        var res_id = parseInt(item.cmd_id) + 1
                        //添加默认res协议
                        $scope.msgFilters[res_id] = res_id;
                        id_logs.push(res_id)
                        for (var j = 0; j < item.rpt_att.length; j++) {
                            var id = item.rpt_att[j]
                            if (id) {
                                $scope.msgFilters[id] = id;
                                id_logs.push(id)
                            }
                        }
                    }
                }
            }
            console.log("msgFilters=%s", id_logs.join(","))
            $scope.msgFilterShow = false
        }
        //新增协议
        $scope.insertProtoData = function () {
            if (!$scope.curProtocol.name) {
                alert("协议名称不正确!")
                return
            }

            if (!$scope.curProtocol.cmd_id || $scope.curProtocol.cmd_id < 0) {
                alert("协议id不正确!")
                return
            }

            var add = $scope.curCase.protocols[$scope.curProtocol.id] ? false : true
            //协议参数
            if ($scope.curProtocol.args) {
                try {
                    JSON.parse($scope.curProtocol.args)
                } catch (err) {
                    alert("参数错误,请检查协议参数json格式是否合法" + err)
                    return
                }
            }
            $scope.curProtocol.args = FormatUtils.formatJson($scope.curProtocol.args)
            //回执关注
            if ($scope.curProtocol.rpt_att) {
                var arr = $scope.curProtocolRptAtt.split(",")
                $scope.curProtocol.rpt_att = []
                for (var i = 0; i < arr.length; i++) {
                    var val = parseInt(arr[i])
                    if (val) {
                        $scope.curProtocol.rpt_att.push(val)
                    }
                }
            }

            if (!$scope.curProtocols) {
                alert("数据异常,请刷新网页再尝试")
                return
            }
            NetUtils.post("/proto_edit", JSON.stringify({
                "data": {
                    id: $scope.curCase.id,
                    data: $scope.curProtocol
                }
            }), function (ok, data) {
                if (!ok) {
                    alert("保存失败")
                    return
                }
                $scope.curCase.protocols[$scope.curProtocol.id] = $scope.curProtocol
                $scope.upProtFilter()
                $scope.upCurProtocolArr()
                if (add) {
                    $scope.newProtocol()
                    alert("添加成功")
                } else {
                    alert("保存成功")
                    $scope.showProtocol(false)
                }
            })
        }
        //新建测试用例
        $scope.newCase = function () {
            $scope.openid = null
            $scope.passwd = null
            $scope.serverAddr = null
            $scope.curCaseName = null
            $scope.setCurProtocols(null)
            $scope.caseRptAtt = ""
            $scope.curCaseIndex = null
        }
        $scope.changeCases = function () {
            var accord = $scope.accordsListFiltr[$scope.curCaseIndex]
            if (accord) {
                $scope.curCase = $scope.getAccordByName(accord.casegroup, accord.name)
                if ($scope.curCase) {
                    $scope.showOperator = true
                    $scope.openid = $scope.curCase.openid
                    $scope.passwd = $scope.curCase.passwd
                    $scope.serverAddr = $scope.curCase.server
                    $scope.curCaseName = $scope.curCase.name
                    $scope.setCurProtocols($scope.curCase.protocols)
                    $scope.caseRptAtt = $scope.curCase.rpt_att.join(",")
                } else {
                    console.log("changeCases curCase is null")
                }
            }
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
        $scope.runHeartBeat = function () {
            var cmd = {}
            var heartArgs = {}
            heartArgs.time = 0
            cmd.id = 1001;
            cmd.args = heartArgs;
            NetUtils.post("/run", {
                "open_id": $scope.openid,
                "cmd_id": cmd.id,
                "data": cmd.args
            }, function (ok, data) {
                if (!ok) {
                    console.log("请求处理失败", data)
                    return
                }
            })
        }
        //运行单条协议
        $scope.runProtocol = function (cmd) {
            if (!$scope.logined) {
                alert("尚未启动")
                return;
            }
            var args_log = `{\n "id":${cmd.cmd_id},\n "name":${cmd.name},\n "args":${cmd.args}\n}`
            $scope.messages += "\n\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]发送:\n" + FormatUtils.prettyFormat(args_log)
            document.getElementById('jsonShow').innerHTML = $scope.messages
            NetUtils.post("/run", {
                "open_id": $scope.openid,
                "cmd_id": cmd.cmd_id,
                "data": cmd.args
            }, function (ok, data) {
                if (!ok) {
                    $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]应答:\n" + FormatUtils.prettyFormat(data)
                    return
                }
                $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]应答:\n" + FormatUtils.prettyFormat(data)
                document.getElementById('jsonShow').innerHTML = $scope.messages
            })
        }
        $scope.runAll = function (cmd) {
            if (!$scope.logined) {
                alert("尚未启动")
                return;
            }

            //添加队列
            for (var i = 0; i < $scope.curProtocolSort.length; i++) {
                var proto = $scope.curProtocolSort[i]
                var add = {
                    cmd_id: proto.cmd_id,
                    name: proto.name,
                    args: proto.args,
                }
                $scope.queueReqList.push(add)
            }
            this.runQueueRq()
        }
        //运行队列请求
        $scope.runQueueRq = function () {
            var req = $scope.queueReqList[0]
            if (!req) {
                return
            }
            var args_log = `{\n "id":${req.cmd_id},\n "name":${req.name},\n "args":${req.args}\n}`
            $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]请求:\n" + FormatUtils.prettyFormat(args_log)
            document.getElementById('jsonShow').innerHTML = $scope.messages
            NetUtils.post("/run", {
                "open_id": $scope.openid,
                "cmd_id": req.cmd_id,
                "data": req.args
            }, function (ok, data) {
                if (!ok) {
                    $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]应答:\n" + FormatUtils.prettyFormat(data)
                    return
                }
                $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "]应答:\n" + FormatUtils.prettyFormat(data)
                document.getElementById('jsonShow').innerHTML = $scope.messages
                $scope.queueReqList.shift();
                $scope.runQueueRq()
            })
        }
        $scope.startRobot = function (cmd) {
            if ($scope.logined) {
                alert("已启动");
                return;
            }

            if (!$scope.serverAddr) {
                alert("请选择服务器");
                return;
            }

            $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "] 开始启动机器人"
            //解析ip和port
            const regex = /\((.*?)\)/g;
            const matches = $scope.serverAddr.match(regex);
            const connections = matches.map(match => match.substring(1, match.length - 1));
            var ipInfo = connections[0].split(":");
            NetUtils.post("/create", {
                "ip": ipInfo[0],
                "port": Number(ipInfo[1]),
                "open_id": $scope.openid,
                "passwd": $scope.passwd
            }, function (ok, data) {
                if (!ok || data.code != 0) {
                    alert("启动失败" + data.msg)
                    return
                }
                $scope.logined = true
                $scope.toggleStatus()
            })
        }
        $scope.stopRobot = function (cmd) {
            if (!$scope.logined) {
                alert("尚未启动");
                return;
            }
            NetUtils.post("/destory", {
                "open_id": $scope.openid
            }, function (ok, data) {
                if (!ok) {
                    alert("停止失败" + data.msg)
                    $scope.messages += "\n停止失败" + data.msg
                    document.getElementById('jsonShow').innerHTML = $scope.messages
                    return
                }
                $scope.logined = false
                $scope.toggleStatus()
            })
        }
        $scope.addItem = function (cmd) {
            $scope.newProtocol()
            $scope.showProtocol(true, {})
        }
        $scope.newProtocol = function(){
            $scope.curProtocol = {
                id: DataUtils.generateUUID(),
                cmd_id: 0,
                name: "",
                time: DataUtils.getNowSecond(),
                args: "",
                rpt_att: []
            }
        }
        $scope.removeItem = function (cmd) {
            NetUtils.post("/proto_del", {
                "data": {
                    id: $scope.curCase.id,
                    proto_id: cmd.id,
                }
            }, function (ok, data) {
                if (!ok) {
                    alert("删除失败")
                    return
                }
                delete $scope.curProtocols[cmd.id]
                $scope.upCurProtocolArr()
            })
        }
        $scope.cleanLogs = function (cmd) {
            $scope.messages = ""
            document.getElementById('jsonShow').innerHTML = $scope.messages
        }
        $scope.toggleStatus = function () {
            if ($scope.logined) {
                $scope.messages += "\n启动成功"
                $scope.robotStatus = "运行中"
                document.getElementById("heartbeat-light").className = "heartbeat-icon light-green"
                document.getElementById('jsonShow').innerHTML = $scope.messages
            } else {
                $scope.messages += "\n[" + new Date().Format("yyyy-MM-dd hh:mm:ss S") + "] 停止成功"
                $scope.robotStatus = "已停止"
                document.getElementById("heartbeat-light").className = "heartbeat-icon light-gray"
                document.getElementById('jsonShow').innerHTML = $scope.messages
            }
        }
        $scope.onCheckboxChange = function (kind) {
            console.log("onCheckboxChange kind=%s", kind)
            if (kind == "msgFilter") {
                this.upProtFilter()
            }
            else if (kind == "rptAtt") {
                this.upProtFilter()
            }
            else if(kind == "login"){
            }
            else if(kind == "all"){
            }
        }
        $scope.copyRoleId = function () {
            DataUtils.copyToClipboard($scope.roleId.toString())
            $scope.copyRoleTip = "完成"
            clearTimeout($scope.copyRoleTime)
            $scope.copyRoleTime = setTimeout(function(){
                $scope.copyRoleTip = "复制"
            },300)
        }

        $scope.gotoLogTop = function () {
            var container = document.getElementById('message_content');
            if (container) {
                container.scrollTop = 0;
                $scope.topCheckbox.msgRoll = false
            }
        }
        $scope.gotoLogBottom = function () {
            var container = document.getElementById('message_content');
            if (container) {
                container.scrollTop = container.scrollHeight;
                $scope.topCheckbox.msgRoll = true
            }
        }
        $scope.changeAccordSelect = function () {
            $scope.curProtocolSelect = $scope.accordSelectSort[$scope.protocolSelectIndex]
            if (!$scope.curProtocolSelect) {
                return
            }
            if(!$scope.curProtocol){
                $scope.newProtocol()
            }
            if($scope.curProtocol.cmd_id != $scope.curProtocolSelect.msg_id){
                $scope.curProtocol.name = $scope.curProtocolSelect.name
                $scope.curProtocol.args = FormatUtils.formatJson(JSON.stringify($scope.curProtocolSelect.fields, null, 4));
                $scope.curProtocol.cmd_id = $scope.curProtocolSelect.msg_id
            }
        }
        $scope.changeCaseGroup = function () {
            $scope.refreshAccordListFiltr()
            if (!$scope.caseEdit) {
                $scope.newCase()
            }
            //设置默认测试用例
            $scope.curCaseIndex = "0"
            $scope.changeCases()
        },
        $scope.refreshAccordListFiltr = function () {
            $scope.accordsListFiltr = []
            for (var key in $scope.accordsList) {
                var accord = $scope.accordsList[key]
                if (accord.casegroup == $scope.caseGroupName) {
                    $scope.accordsListFiltr.push(accord)
                }
            }
            $scope.accordsListFiltr.sort(function (a, b) {
                    return a.time - b.time
                })
            }
        $scope.getAccordByName = function (group, name) {
            for (var key in $scope.accordsList) {
                var accord = $scope.accordsList[key]
                if (accord.casegroup == group && accord.name == name) {
                    return accord
                }
            }
            return null
        }
        $scope.changeAccordGroup = function(){
            $scope.curProtocolGroup = $scope.accordGroupSort[$scope.accordGroupIndex].group
            $scope.accordSelectSort = []
            for(var key in $scope.curProtocolGroup){
                var protocol = $scope.curProtocolGroup[key]
                $scope.accordSelectSort.push(protocol)
            }
            $scope.accordSelectSort.sort(function(a, b){
                return a.msg_id - b.msg_id
            })
        }
        $scope.getAccordGroupCount = function(name){
            var result = {
                accord_count:0,
                protocol_count:0
            }
            for(var key in $scope.accordsList){
                var accord = $scope.accordsList[key]
                if(!accord){
                    continue
                }
                if(accord.casegroup == name){
                    result.accord_count++
                    result.protocol_count += DataUtils.getMapCount(accord.protocols)
                }
            }
            return result
        }
        //清理协议
        $scope.clearAccordByGroup = function(name){
            for(var key in $scope.accordsList){
                var accord = $scope.accordsList[key]
                if(!accord){
                    continue
                }
                if(accord.casegroup == name){
                    delete $scope.accordsList[key]
                }
            }
        }
    });
</script>

</html>

<style>
    pre {
    outline: 1px solid #ccc;
}

.string {
    color: green;
}

.number {
    color: darkorange;
}

.boolean {
    color: blue;
}

.null {
    color: magenta;
}

.key {
    color: red;
}

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

.login-button.clone-button {
    background: #27d99f;
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
    width: calc(100% - 450px);
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

.checkbox {
    /* display: flex; */
    flex-direction: row;
}

.checkbox-inline {
    margin-right: 10px;
}


.srv-li {
    margin-bottom: 10px;
    border: 1px solid #ccc;
    padding: 10px;
    border-radius: 5px;
    text-align: center;
}

.edit-btn {
    padding: 5px 10px;
    margin-left: 10px;
    background-color: rgb(39, 217, 159);
    border: 1px solid #ccc;
    border-radius: 5px;
    cursor: pointer;
}

.del-btn {
    padding: 5px 10px;
    background-color: rgb(245, 108, 108);
    border: 1px solid #ccc;
    border-radius: 5px;
    cursor: pointer;
}

.checke{
    position: relative;
    -webkit-appearance: none;
    width:40px;
    height: 20px;
    line-height: 10px;
    background: #eee;
    border-radius: 30px;
    outline: none;
}
.checke:before{
    position: absolute;
    left: 0;
    content: '';
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: white;
    box-shadow: 0px 0px 5px #ddd;
    transition: all 0.2s linear;
}
.checke:checked{
   background: rgb(39, 217, 159);
}
.checke:checked:before{
    left: 20px;
    transition: all 0.2s linear;
}

.log-fast-btn {
    height: 50px;
    width: 55px;
    padding: 0px 10px;
    margin-left: 50px;
    background-color: rgb(39, 217, 159);
    border: 1px solid #ccc;
    cursor: pointer;
    opacity: .3;
    transition: opacity 0.5s;
    border-radius: 50px;
}
.log-fast-btn:hover {
    opacity: 1;
    cursor: pointer;
}

.pre-text { 
    white-space: pre-wrap;
}
</style>
]]