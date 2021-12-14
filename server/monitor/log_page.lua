-- luacheck: ignore
return [[
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="author" content="quanta">
    <meta name="description" content="quanta log">
    <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <title>Log Console</title>
    <link rel="icon" href="http://kyrieliu.cn/kyrie.ico">
    <link rel="stylesheet" href="http://cdn.bootcss.com/bootstrap/3.3.0/css/bootstrap.min.css">
</head>
<style>
    html,body,div,h1,h2,h3,h4,h5,h6,p,span{
        padding: 0;
        margin: 0;
    }
    body{
        padding-top: 10px;
        overflow: auto;
    }
    .logDumpContainer {
        float: left;
        border: 1px solid black;
        height: 640px;
        width: 30%;
        margin-top:50px;
        overflow: auto;
    }
    .logContainer {
        padding: 2px;
        border: 1px solid black;
        margin-top:50px;
        height: 640px;
        width: 70%;
        overflow: auto;
    }
    .historyMsg{
        top: 5px;
        border: 1px solid black;
        height: 554px;
        padding: 3px;
        overflow: auto;
    }
    .newMsg{
        text-align: left;
        margin-top: 5px;
    }
    .myMsg{
        background-color: grey;
        color: white;
        text-align: left;
        margin-top: 5px;
    }
    .control{
        border: 1px solid black;
        height: 80px;
    }
    .control-row{
        margin-top: 20px;
    }
    .inputMsg{
        height: 30px !important;
        resize: none;
    }
    .attachBtn{
        height: 30px;
    }
    .detachBtn{
        height: 30px;
    }
    footer{
        text-align: center;
    }
</style>
<body>
<div class="container gm-container">
    <!-- gm dump -->
    <div class="logDumpContainer">
        <div id="logTree" class=""></div>
    </div>
    <!-- 消息内容 -->
    <div class="logContainer">
        <div class="col-md-12 col-sm-12 historyMsg" id="historyMsg">
        </div>
        <div class="col-md-12 col-sm-12 control">
            <div class="row control-row">
                <div class="col-md-8 col-sm-8">
                    <textarea id="inputMsg" class="inputMsg form-control"></textarea>
                </div>
                <div class="col-md-2 col-sm-2">
                    <button id="attachBtn" class="form-control attachBtn btn btn-primary">attach</button>
                </div>
                <div class="col-md-2 col-sm-2">
                    <button id="detachBtn" class="form-control detachBtn btn btn-primary">detach</button>
                </div>
            </div>
        </div>
    </div>
</div>
<footer>
    <small>Designed and built by <a href="https://github.com/xiyoo0812/quanta" target="_blank">quanta</a></small>
</footer>
</body>
<script src="http://ajax.googleapis.com/ajax/libs/jquery/1.9.1/jquery.min.js"></script>
<script src="http://jonmiles.github.io/bootstrap-treeview/js/bootstrap-treeview.js"></script>
<script type="text/javascript">
    window.onload = function(){
        var gmlog = new GMConsole();
        gmlog.init();
        //self.setInterval("clock()",1000);
    };
    var GMConsole = function(){
    };
    GMConsole.prototype = {
        init: function(){
            var that = this;
            // 加载节点列表
            $.ajax({
                url:"/status",
                type: "GET",
                dataType: "json",
                contentType: "utf-8",
                success: function (result) {
                    var nodes = [];
                    that.nodelist = result;
                    for (var token in result) {
                        var node = result[token];
                        if (node) {
                            nodes.push({ text : node.service + "-" + node.index, token : token });
                        }
                    };
                    that._showNodes(nodes);
                    that.session_id = 0;
                },
                error: function(status) {
                    document.write(JSON.stringify(status));
                }
            });

            //attachBtn事件
            document.getElementById('attachBtn').addEventListener('click', function(){
                that.logging = true;
                that._sendRequest();
            }, false);
            //detachBtn事件
            document.getElementById('detachBtn').addEventListener('click', function(){
                that.logging = false;
            }, false);
        },

        _showNodes: function(nodes) {
            var that = this;
            $('#logTree').treeview({data: nodes});
            //logTree事件
            $('#logTree').on('nodeSelected', function(event, data) {
                var token = data.token;
                var node = that.nodelist[token];
                if (node) {
                    that.logging = false;
                    that.service_id = node.service_id;
                    var msg = "<pre>service: " + node.service + "  index: " + node.index + "</pre>";
                    that._displayNewMsg("historyMsg", msg, "myMsg");
                }
            });
        },

        _sendRequest: function() {
            var that = this;
            var inputMsg = document.getElementById('inputMsg');
            var filters = inputMsg.value
            $.ajax({
                url:"/command",
                type: "POST",
                dataType: "json",
                contentType: "utf-8",
                data: JSON.stringify({ data : msg, service_id : that.service_id, rpc : "rpc_show_log", filters : filters }),
                success: function (result) {
                    if (result.code != 0) {
                        that._displayNewMsg("historyMsg", result.msg, "newMsg");
                        return
                    }
                    that.session_id = result.session_id;
                    var messages = result.msg;
                    for (var index in messages) {
                        var log = messages[index];
                        that._displayNewMsg("historyMsg", log, "newMsg");
                    }
                },
                error: function(status) {
                    var data = status.responseText;
                    data = data.replace(new RegExp("\n",'g'),"<br/>");
                    that._displayNewMsg("historyMsg", data, "newMsg");
                }
            });
            inputMsg.value = "";
            inputMsg.focus();
        },

        _displayNewMsg: function(container_id, msg, type){
            var container = document.getElementById(container_id);
            var p = document.createElement('p');
            var text = document.createElement("span");
            text.innerHTML = msg;
            p.setAttribute('class', type);
            p.appendChild(text);
            container.appendChild(p);
            container.scrollTop = container.scrollHeight;
        },
    };
</script>
</html>
]]
