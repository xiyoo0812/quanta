-- luacheck: ignore
return [[
<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="author" content="quanta">
    <meta name="description" content="quanta gm">
    <meta name="viewport" content="width=device-width,initial-scale=1,user-scalable=no">
    <meta http-equiv="X-UA-Compatible" content="IE=edge,chrome=1">
    <title>GM Console</title>
    <link rel="icon" href="http://kyrieliu.cn/kyrie.ico">

    <!-- 新 Bootstrap 核心 CSS 文件 -->
    <link rel="stylesheet" href="http://cdn.bootcss.com/bootstrap/3.3.0/css/bootstrap.min.css">
</head>

<style>
    html,body,div,h1,h2,h3,h4,h5,h6,p,span{
        padding: 0;
        margin: 0;
        overflow: hidden;
    }

    body{
        padding-top: 10px;
        overflow: auto;
    }

    .banner{
        border: 1px solid black;
        height: 20px;

    }

    .gmDumpContainer {
        float: left;
        border: 1px solid black;
        height: 600px;
        width: 30%;
        margin-top:100px;
        overflow: auto;
    }
    .gmContainer {
        float: left;
        border: 1px solid black;
        margin-top:100px;
        height: 600px;
        width: 70%;
        overflow: auto;
    }

    .gmDump {
        width: 800px;
    }

    .command_arg {
        display:inline-block;
        min-width: 100px;
        color: red;
    }
    .historyMsg{
        float: left;
        top: 10px;
        border: 1px solid black;
        height: 500px;
        padding: 5px;

        overflow: auto;
    }

    .newMsg{
        text-align: left;
        margin-top: 5px;
    }

    .timespan{
        color: #ddd;
    }

    .myMsg{
        background-color: grey;
        color: white;
        text-align: left;
        margin-top: 5px;
    }

    /*系统消息*/
    .system{
        text-align: left;
        background-color: grey;
        color: white;
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

    .sendBtn{
        height: 30px;
    }

    footer{
        text-align: center;
    }

    .info{
        color: white;
        font-size: 10px;
    }

    .nickWrapper{
        display: none;
    }

    /* Tablets: 768px */
    @media screen and (max-width: 760px){

        .historyMsg{
            font-size: 10px;
            border: 0px;
            height: 330px;
            padding: 5px;
            position: relative;
            overflow: auto;
        }

        .banner{
            border: 0px;
            border-bottom: 1px solid gray;
        }

        .inputMsg{
            margin-bottom: 2px;
        }

        .control{
            border: 0px;
        }

        footer{
            font-size: 10px;
        }
    }
</style>

<body>

<div class="container gm-container">
    <!-- gm dump -->
    <div class="gmDumpContainer">
        <div class="gmDump" id="gm_dump">

        </div>
    </div>

    <!-- 消息内容 -->
    <div class="gmContainer">
        <div class="col-md-10 col-md-offset-1 col-sm-12 historyMsg" id="historyMsg">
        </div>

        <div class="col-md-10 col-md-offset-1 col-sm-12 control">
            <div class="row control-row">
                <div class="col-md-8 col-sm-8">
                    <textarea id="inputMsg" class="inputMsg form-control"></textarea>
                </div>
                <div class="col-md-4 col-sm-4">
                    <button id="sendBtn" class="form-control sendBtn btn btn-primary">send</button>
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

            // 加载命令列表
            $.ajax({
                url:"/gmlist",
                type: "GET",
                dataType: "json",
                contentType: "utf-8",
                success: function (result) {
                    for (var cmd_name in result) {
                        var cmd_data = result[cmd_name];
                        that._displayNewMsg("gm_dump", cmd_name + "(" + cmd_data.desc + ")", "system");
                        that._displayCmdArgs("args:" + cmd_data.command);
                    };
                    document.getElementById("gm_dump").scrollTop = 0;
                },
                error: function(status) {
                    //document.write(JSON.stringify(status));
                }
            });

            //发送按钮和inputMsg监听事件
            document.getElementById('sendBtn').addEventListener('click', function(){
                that._sendCommand();
            }, false);

            document.getElementById('inputMsg').addEventListener('keyup', function(e){
                if (e.keyCode == 13){
                    that._sendCommand();
                }
            }, false);
        },

        _sendCommand: function() {
            var that = this

            var inputMsg = document.getElementById('inputMsg');
            var msg = inputMsg.value.replace('\n','');
            if (msg == ''){
                inputMsg.focus();
                return;
            }

            that._displayNewMsg("historyMsg", msg, "myMsg");
            msg = msg.replace(new RegExp(" ",'g'),"/");

            $.ajax({
                url:"/command",
                type: "POST",
                dataType: "json",
                contentType: "utf-8",
                data: { data : inputMsg.value},
                success: function (result) {
                    if (result.code != 0) {
                        that._displayNewMsg("historyMsg", result.msg, "newMsg");
                        return
                    }
                    result = result.ret
                    if (typeof(result) == "object") {
                        var data = JSON.stringify(result, null, "    ");
                        data = "<pre>" + data + "</pre>";
                        that._displayNewMsg("historyMsg", data, "newMsg");
                    } else {
                        var data = result;
                        data = "<pre>" + data + "</pre>";
                        that._displayNewMsg("historyMsg", data, "newMsg");
                    }
                },
                error: function(status) {
                    //var data = status.responseText;
                    //data = data.replace(new RegExp("\n",'g'),"<br/>");
                    //that._displayNewMsg("historyMsg", data, "newMsg");
                }
            });

            inputMsg.value = "";
            inputMsg.focus();
        },

        _displayCmdArgs: function(arg){
            var container = document.getElementById("gm_dump");

            var p = document.createElement('p');
            p.setAttribute('class', "newMsg");

            var text_arg = document.createElement("span");
            text_arg.setAttribute('class', "command_arg");
            text_arg.innerHTML = arg;

            p.appendChild(text_arg);
            container.appendChild(p);
        },

        _displayNewMsg: function(container_id, msg, type){
            var container = document.getElementById(container_id);

            var p = document.createElement('p');
            p.setAttribute('class', type);

            //var text = document.createTextNode(msg);
            var text = document.createElement("span");
            text.innerHTML = msg;

            p.appendChild(text);
            container.appendChild(p);

            //控制滚动条自动滚到底部
            container.scrollTop = container.scrollHeight;
        },
    };
</script>

</html>
]]
