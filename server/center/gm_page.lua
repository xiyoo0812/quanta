-- luacheck: ignore
return [[
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="author" content="quanta">
    <meta name="description" content="quanta console">
    <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <title>GM Console</title>
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/twitter-bootstrap/3.4.1/css/bootstrap.min.css">
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
    .gmDumpContainer {
        float: left;
        border: 1px solid black;
        height: 800px;
        width: 30%;
        margin-top:30px;
        overflow: auto;
    }
    .gmContainer {
        padding: 2px;
        border: 1px solid black;
        margin-top:30px;
        height: 800px;
        width: 70%;
        overflow: auto;
    }
    .historyMsg{
        top: 5px;
        border: 1px solid black;
        height: 660px;
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
        height: 130px;
    }
    .control-row{
        margin-top: 10px;
    }
    .inputMsg{
        height: 110px !important;
        resize: none;
    }
    .sendBtn{
        height: 100px;
    }
    footer{
        text-align: center;
    }
</style>
<body>
<div class="container gm-container">
    <!-- gm dump -->
    <div class="gmDumpContainer">
        <div id="consoleTree" class=""></div>
    </div>
    <!-- 消息内容 -->
    <div class="gmContainer">
        <div class="col-md-12 col-sm-12 historyMsg" id="historyMsg">
        </div>
        <div class="col-md-12 col-sm-12 control">
            <div class="row control-row">
                <div class="col-md-10 col-sm-10">
                    <textarea id="inputMsg" class="inputMsg form-control"></textarea>
                </div>
                <div class="col-md-2 col-sm-2" style="padding:5px">
                    <button id="send" class="form-control sendBtn btn btn-primary">send</button>
                </div>
            </div>
        </div>
    </div>
</div>
<footer>
    <small>Designed and built by <a href="https://github.com/xiyoo0812/quanta" target="_blank">quanta</a></small>
</footer>
</body>
<script src="https://cdnjs.cloudflare.com/ajax/libs/jquery/3.6.1/jquery.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/bootstrap-treeview/1.2.0/bootstrap-treeview.min.js"></script>
<script type="text/javascript">
    window.onload = function(){
        var gmconsole = new GMConsole();
        gmconsole.init();
    };
    var GMConsole = function(){
    };
    GMConsole.prototype = {
        init: function(){
            var that = this;
            var cmd_index = 0;
            var historyCmds = [];
            var treeNodes = [ {}, {} ];
            // 加载命令列表
            $.ajax({
                url:"/gmlist",
                type: "GET",
                dataType: "json",
                contentType: "utf-8",
                success: function (res) {
                    treeNodes[0] = res;
                    that._showConsole(treeNodes);
                },
                error: function(status) {
                    document.write(JSON.stringify(status));
                }
            });

            // 加载JSON接口列表
            $.ajax({
                url:"/monitors",
                type: "GET",
                dataType: "json",
                contentType: "utf-8",
                success: function (res) {
                    treeNodes[1] = res;
                    that._showConsole(treeNodes);
                },
                error: function(status) {
                    document.write(JSON.stringify(status));
                }
            });

            //sendMsg事件
            document.getElementById('send').addEventListener('click', function(){
                that._sendCommand(historyCmds);
                cmd_index = historyCmds.length
            }, false);
            
            //inputMsg事件
            document.getElementById('inputMsg').addEventListener('keyup', function(e){
                if (e.keyCode == 13 && e.ctrlKey){
                    that._sendCommand(historyCmds);
                    cmd_index = historyCmds.length
                } else if (e.keyCode == 38){
                    if (cmd_index > 0) cmd_index = cmd_index - 1
                    that._showCommand(historyCmds[cmd_index])
                } else if (e.keyCode == 40){
                    if (cmd_index < historyCmds.length - 1) cmd_index = cmd_index + 1
                    that._showCommand(historyCmds[cmd_index])
                }
            }, false);
        },

        _showCommand: function(cmd) {
            var inputMsg = document.getElementById('inputMsg');
            inputMsg.value = cmd;
            inputMsg.focus();
        },

        _showConsole: function(treeNodes) {
            var that = this;
            $('#consoleTree').treeview({data: treeNodes});
            //consoleTree事件
            $('#consoleTree').on('nodeSelected', function(event, data) {
                if (data.tag == "gm") {
                    //参数数组
                    var arg_arr = ["<pre>命令: ", data.text,"  参数: ", data.command];
                    if (data.example) {
                        arg_arr.push("<br>示例：");
                        arg_arr.push(data.example);
                    }
                    if (data.tip) {
                        arg_arr.push("<br>说明：");
                        arg_arr.push(data.tip);
                    }
                    arg_arr.push("</pre>");
                    var msg = arg_arr.join("")
                    that._displayNewMsg("historyMsg", msg, "myMsg");
                    that._showCommand(data.name + " ")
                } else if (data.tag == "log") {
                    window.open("http://" + data.text);
                }
            });
        },
        
        _isJson(data){
            try{
                JSON.parse(data);
            }
            catch(err){
                return false;
            }
            return true;
        },

        _inputMsgTrim(historyCmds){
            var that = this;
            var inputMsg = document.getElementById('inputMsg');
            var msg = inputMsg.value.replace('\n', '');
            if (msg == ''){
                inputMsg.focus();
                return null;
            }
            historyCmds.push(msg);
            var result = { cmdType : "cmd", data : {} };
            that._displayNewMsg("historyMsg", msg, "myMsg");
            if(that._isJson(msg)){
                result.cmdType = "json";
                result.data = JSON.stringify({ data : JSON.parse(msg) });
                return result;
            }
            result.data = JSON.stringify({ data : msg })
            return result;
        },

        _sendCommand: function(historyCmds) {
            var that = this;
            var result = that._inputMsgTrim(historyCmds);
            if(!result){
                that._displayNewMsg("historyMsg", "error", "newMsg");
                return;
            }
            var url = result.cmdType == "cmd" ? "/command" : "/message";
            $.ajax({
                url: url,
                type: "POST",
                dataType: "json",
                contentType: "utf-8",
                data: result.data,
                success: function (res) {
                    var result = res.msg
                    if (res.code != 0) {
                        var data = "<pre>" + result + "</pre>";
                        that._displayNewMsg("historyMsg", data, "newMsg");
                        return
                    }
                    if (typeof(result) == "object") {
                        var data = JSON.stringify(result, null, "    ");
                        data = "<pre>" + data + "</pre>";
                        that._displayNewMsg("historyMsg", data, "newMsg");
                    } else {
                        var data = "<pre>" + result + "</pre>";
                        that._displayNewMsg("historyMsg", data, "newMsg");
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
