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
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/fontawesome-free-v6@1.0.1/css/all.min.css">
</head>
<style>
html, body, div, h1, h2, h3, h4, h5, h6, p, span, pre {
    padding: 0;
    margin: 0;
}
body {
    padding-top: 10px;
    overflow: auto;
    font-family: Consolas, Monaco, "Courier New", monospace;
    font-size: 13px;
    background: #f0f2f5;
}
.gm-container {
    display: flex;
    padding: 0 10px;
}
.gmDumpContainer {
    border: 1px solid #d0d5dd;
    border-radius: 8px;
    height: 800px;
    flex: 0 0 30%;
    margin-right: 15px;
    margin-top: 30px;
    overflow: auto;
    background: #fafbfc;
    box-shadow: 0 2px 6px rgba(0,0,0,.06);
}
.gmContainer {
    border: 1px solid #d0d5dd;
    border-radius: 8px;
    margin-top: 30px;
    height: 800px;
    flex: 1;
    display: flex;
    flex-direction: column;
    overflow: hidden;
    background: #ffffff;
    box-shadow: 0 2px 6px rgba(0,0,0,.06);
}
.historyMsg {
    flex: 1;
    margin: 5px;
    padding: 8px;
    overflow: auto;
    background: #ffffff;
    border-radius: 6px;
    display: flex;
    flex-direction: column;
    gap: 5px;
}
.historyMsg .msg-item {
    padding: 8px 12px;
    border-radius: 6px;
    border-left: 4px solid transparent;
    white-space: pre-wrap;
    word-wrap: break-word;
    line-height: 1.6;
    font-size: 13px;
}
.historyMsg .msg-cmd-label {
    font-weight: 700;
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 3px;
    display: flex;
    align-items: center;
    gap: 4px;
}
.historyMsg .myMsg {
    background-color: #fff3e0;
    color: #e65100;
    border-left-color: #ff9800;
}
.historyMsg .myMsg .msg-cmd-label { color: #ef6c00; }
.historyMsg .newMsg {
    background-color: #e8f5e9;
    color: #1b5e20;
    border-left-color: #4caf50;
}
.historyMsg .newMsg .msg-cmd-label { color: #2e7d32; }
.historyMsg .errMsg {
    background-color: #ffebee;
    color: #b71c1c;
    border-left-color: #ef5350;
}
.historyMsg .errMsg .msg-cmd-label { color: #c62828; }
.historyMsg .cmdInfo {
    background-color: #e3f2fd;
    color: #0d47a1;
    border-left-color: #1e88e5;
}
.historyMsg .cmdInfo .msg-cmd-label { color: #1565c0; }
.historyMsg .cmdInfo .field-row {
    padding: 1px 0;
}
.historyMsg .cmdInfo .field-key {
    font-weight: 600;
    color: #1565c0;
}
.historyMsg .json-output {
    font-family: Consolas, Monaco, "Courier New", monospace;
    white-space: pre-wrap;
}
.control {
    height: 130px;
    margin: 5px;
    flex-shrink: 0;
    border-top: 1px solid #e9ecef;
    padding-top: 5px;
}
.control-row {
    height: 100%;
    margin: 0;
}
.inputMsg {
    height: 100% !important;
    resize: none;
    font-family: Consolas, Monaco, "Courier New", monospace;
    font-size: 13px;
    background: #fafbfc;
    border: 1px solid #dee2e6;
}
.inputMsg:focus {
    border-color: #86b7fe;
    box-shadow: 0 0 0 0.2rem rgba(13,110,253,.15);
}
.sendBtn {
    height: 100%;
    font-weight: 600;
}
footer {
    text-align: center;
    margin-top: 10px;
    color: #6c757d;
    font-size: 12px;
}
.treeSearch {
    width: 96%;
    padding: 6px 10px;
    margin: 6px;
    border: 1px solid #d0d5dd;
    border-radius: 5px;
    box-sizing: border-box;
    font-size: 13px;
}
.treeSearch:focus {
    outline: none;
    border-color: #86b7fe;
    box-shadow: 0 0 0 0.15rem rgba(13,110,253,.15);
}
#consoleTree {
    padding: 3px 6px;
    font-size: 13px;
}
.tree-node {
    user-select: none;
}
.tree-row {
    padding: 3px 6px;
    cursor: pointer;
    border-radius: 4px;
    display: flex;
    align-items: center;
    gap: 4px;
    transition: background-color 0.1s;
}
.tree-row:hover {
    background-color: #eef1f4;
}
.tree-icon {
    width: 18px;
    text-align: center;
    flex-shrink: 0;
    font-size: 12px;
    color: #90a4ae;
}
.tree-icon.folder { color: #ffa726; }
.tree-icon.file { color: #42a5f5; }
.tree-icon.log { color: #ab47bc; }
.tree-label {
    flex: 1;
    padding-left: 2px;
    word-break: break-all;
}
.tree-children {
    padding-left: 22px;
    border-left: 1px solid #e0e4e8;
    margin-left: 10px;
}
.tree-node.selected > .tree-row {
    background-color: #0d6efd;
    color: white;
}
.tree-node.selected > .tree-row .tree-icon {
    color: white;
}
</style>
<body>
<div class="gm-container">
    <div class="gmDumpContainer">
        <input type="text" id="treeSearch" placeholder="搜索节点..." class="treeSearch">
        <div id="consoleTree"></div>
    </div>
    <div class="gmContainer">
        <div class="historyMsg" id="historyMsg"></div>
        <div class="control">
            <div class="row control-row" style="height:100%;">
                <div class="col-10" style="height:100%;">
                    <textarea id="inputMsg" class="inputMsg form-control" placeholder="输入 GM 命令..."></textarea>
                </div>
                <div class="col-2" style="height:100%; padding:5px;">
                    <button id="send" class="form-control sendBtn btn btn-primary">
                        <i class="fas fa-paper-plane"></i> Send
                    </button>
                </div>
            </div>
        </div>
    </div>
</div>
<footer>
    <small>Designed and built by <a href="https://github.com/xiyoo0812/quanta" target="_blank">quanta</a></small>
</footer>

<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"></script>

<script type="text/javascript">
window.onload = function(){
    var gmconsole = new GMConsole();
    gmconsole.init();
};

var SimpleTree = {
    render: function(containerId, nodes) {
        var container = document.getElementById(containerId);
        container.innerHTML = '';
        if (!nodes || !nodes.length) return;
        var root = document.createElement('div');
        root.className = 'tree-root';
        nodes.forEach(function(node) {
            root.appendChild(SimpleTree._buildNode(node, 0));
        });
        container.appendChild(root);
    },
    
    _getIcon: function(node, isOpen) {
        if (node.tag == "log") {
            return '<i class="fas fa-file-lines"></i>';
        }
        var hasChildren = node.nodes && node.nodes.length > 0;
        if (hasChildren) {
            return isOpen 
                ? '<i class="fas fa-folder-open"></i>' 
                : '<i class="fas fa-folder"></i>';
        }
        if (node.tag == "gm") {
            return '<i class="fas fa-terminal"></i>';
        }
        return '<i class="fas fa-file"></i>';
    },
    
    _buildNode: function(node, level) {
        var wrap = document.createElement('div');
        wrap.className = 'tree-node';
        wrap.setAttribute('data-level', level);
        wrap._node = node;
        wrap._hasChildren = node.nodes && node.nodes.length > 0;
        
        var hasChildren = wrap._hasChildren;
        
        var row = document.createElement('div');
        row.className = 'tree-row';
        
        // 图标列
        var iconSpan = document.createElement('span');
        var iconClass = 'tree-icon';
        if (hasChildren) iconClass += ' folder';
        else if (node.tag == "gm") iconClass += ' file';
        else if (node.tag == "log") iconClass += ' log';
        else iconClass += ' file';
        iconSpan.className = iconClass;
        // 默认：第一级（level===0）展开，其他级别折叠
        var defaultExpand = (level === 0);
        iconSpan.innerHTML = SimpleTree._getIcon(node, defaultExpand);
        row.appendChild(iconSpan);
        
        // 节点标签
        var label = document.createElement('span');
        label.className = 'tree-label';
        label.textContent = node.text || '';
        row.appendChild(label);
        
        wrap.appendChild(row);
        
        // 子节点容器
        if (hasChildren) {
            var children = document.createElement('div');
            children.className = 'tree-children';
            children.style.display = defaultExpand ? 'block' : 'none'; // 第一级默认展开
            node.nodes.forEach(function(child) {
                children.appendChild(SimpleTree._buildNode(child, level + 1));
            });
            wrap.appendChild(children);
            
            // 整行点击：切换展开/折叠 + 选中（手风琴效果）
            row.addEventListener('click', function(e) {
                e.stopPropagation();
                
                var isExpanded = children.style.display !== 'none';
                if (isExpanded) {
                    // 折叠当前节点
                    children.style.display = 'none';
                    iconSpan.innerHTML = SimpleTree._getIcon(node, false);
                } else {
                    // 展开前关闭所有同级兄弟节点
                    var parentWrap = wrap.parentElement;
                    if (parentWrap) {
                        var siblingNodes = parentWrap.querySelectorAll(':scope > .tree-node');
                        siblingNodes.forEach(function(sib) {
                            if (sib !== wrap) {
                                var sibChildren = sib.querySelector(':scope > .tree-children');
                                if (sibChildren && sibChildren.style.display !== 'none') {
                                    sibChildren.style.display = 'none';
                                    var sibIcon = sib.querySelector(':scope > .tree-row > .tree-icon');
                                    if (sibIcon) {
                                        if (sib._hasChildren) {
                                            sibIcon.innerHTML = SimpleTree._getIcon(sib._node, false);
                                        } else {
                                            sibIcon.innerHTML = SimpleTree._getIcon(sib._node, false);
                                        }
                                    }
                                }
                            }
                        });
                    }
                    // 展开当前节点
                    children.style.display = 'block';
                    iconSpan.innerHTML = SimpleTree._getIcon(node, true);
                }
                
                // 选中节点
                document.querySelectorAll('.tree-node.selected').forEach(function(el) {
                    el.classList.remove('selected');
                });
                wrap.classList.add('selected');
                var event = new CustomEvent('treeNodeSelected', { detail: node });
                document.dispatchEvent(event);
            });
        } else {
            // 叶子节点：点击只触发选中
            row.addEventListener('click', function(e) {
                e.stopPropagation();
                document.querySelectorAll('.tree-node.selected').forEach(function(el) {
                    el.classList.remove('selected');
                });
                wrap.classList.add('selected');
                var event = new CustomEvent('treeNodeSelected', { detail: node });
                document.dispatchEvent(event);
            });
        }
        
        return wrap;
    },
    
    filterNodes: function(nodes, term) {
        if (!term.trim()) return nodes;
        var lowerTerm = term.toLowerCase();
        
        function matchNode(node) {
            var selfMatch = (node.text && node.text.toLowerCase().indexOf(lowerTerm) !== -1) ||
                           (node.name && node.name.toLowerCase().indexOf(lowerTerm) !== -1);
            var childMatches = [];
            if (node.nodes) {
                node.nodes.forEach(function(child) {
                    var m = matchNode(child);
                    if (m) childMatches.push(m);
                });
            }
            if (selfMatch || childMatches.length > 0) {
                var result = Object.assign({}, node);
                result.nodes = childMatches.length > 0 ? childMatches : (selfMatch ? node.nodes : []);
                return result;
            }
            return null;
        }
        
        var result = [];
        nodes.forEach(function(node) {
            var m = matchNode(node);
            if (m) result.push(m);
        });
        return result;
    }
};

// ==================== GM Console ====================
var GMConsole = function(){};

GMConsole.prototype = {
    init: function(){
        var that = this;
        var cmd_index = 0;
        var historyCmds = [];
        var oriTreeNodes = null;

        fetch('/gmlist', { headers: { 'Content-Type': 'application/json' } })
            .then(function(r) { return r.json(); })
            .then(function(res) {
                var nodes = Array.isArray(res) ? res : [res];
                oriTreeNodes = nodes;
                SimpleTree.render('consoleTree', nodes);
            })
            .catch(function(err) {
                that._displayNewMsg("historyMsg", "加载命令列表失败: " + JSON.stringify(err), "errMsg", "✘ 错误");
            });
        
        document.getElementById('treeSearch').addEventListener('input', function(e) {
            if (!oriTreeNodes) return;
            var term = e.target.value;
            if (!term.trim()) {
                SimpleTree.render('consoleTree', oriTreeNodes);
                return;
            }
            var filtered = SimpleTree.filterNodes(oriTreeNodes, term);
            SimpleTree.render('consoleTree', filtered);
            // 搜索结果全部展开
            document.querySelectorAll('#consoleTree .tree-node').forEach(function(nodeEl) {
                var children = nodeEl.querySelector(':scope > .tree-children');
                if (children) {
                    children.style.display = 'block';
                    var icon = nodeEl.querySelector(':scope > .tree-row > .tree-icon');
                    if (icon && nodeEl._hasChildren) {
                        icon.innerHTML = SimpleTree._getIcon(nodeEl._node, true);
                    }
                }
            });
        });

        document.addEventListener('treeNodeSelected', function(e) {
            var node = e.detail;
            if (node.tag == "gm") {
                that._displayCmdInfo("historyMsg", node);
                that._showCommand(node.name + " ");
            } else if (node.tag == "log") {
                window.open("http://" + node.text);
            }
        });

        document.getElementById('send').addEventListener('click', function(){
            that._sendCommand(historyCmds);
            cmd_index = historyCmds.length;
        });

        document.getElementById('inputMsg').addEventListener('keydown', function(e){
            if (e.key == "Enter"){
                if (e.shiftKey) return;
                e.preventDefault();
                that._sendCommand(historyCmds);
                cmd_index = historyCmds.length;
                return;
            }
            if (e.key == 'ArrowUp'){
                if (e.ctrlKey || e.shiftKey) return;
                if (cmd_index > 0) cmd_index--;
                that._showCommand(historyCmds[cmd_index] || '');
                return;
            }
            if (e.key == 'ArrowDown'){
                if (e.ctrlKey || e.shiftKey) return;
                if (cmd_index < historyCmds.length - 1) cmd_index++;
                that._showCommand(historyCmds[cmd_index] || '');
                return;
            }
        });
    },

    _showCommand: function(cmd) {
        var inputMsg = document.getElementById('inputMsg');
        inputMsg.value = cmd;
        inputMsg.focus();
    },

    _isJson: function(data){
        try { JSON.parse(data); } catch(err) { return false; }
        return true;
    },

    _displayCmdInfo: function(container_id, node) {
        var container = document.getElementById(container_id);
        var div = document.createElement('div');
        div.className = 'msg-item cmdInfo';
        
        var label = document.createElement('div');
        label.className = 'msg-cmd-label';
        label.innerHTML = '<i class="fas fa-info-circle"></i> 命令说明';
        div.appendChild(label);
        
        var nameRow = document.createElement('div');
        nameRow.className = 'field-row';
        nameRow.innerHTML = '<span class="field-key">命令：</span>' + 
            '<code style="background:#bbdefb;padding:1px 5px;border-radius:3px;font-weight:bold;">' + 
            (node.text || '') + '</code>';
        div.appendChild(nameRow);
        
        if (node.command) {
            var cmdRow = document.createElement('div');
            cmdRow.className = 'field-row';
            cmdRow.innerHTML = '<span class="field-key">参数：</span>' + node.command;
            div.appendChild(cmdRow);
        }
        if (node.example) {
            var exRow = document.createElement('div');
            exRow.className = 'field-row';
            exRow.innerHTML = '<span class="field-key">示例：</span><span style="color:#0d47a1;">' + node.example + '</span>';
            div.appendChild(exRow);
        }
        if (node.tip) {
            var tipRow = document.createElement('div');
            tipRow.className = 'field-row';
            tipRow.innerHTML = '<span class="field-key">说明：</span>' + node.tip;
            div.appendChild(tipRow);
        }
        
        container.appendChild(div);
        container.scrollTop = container.scrollHeight;
    },

    _displayNewMsg: function(container_id, msg, type, labelText) {
        var container = document.getElementById(container_id);
        var div = document.createElement('div');
        div.className = 'msg-item ' + type;
        
        if (labelText) {
            var label = document.createElement('div');
            label.className = 'msg-cmd-label';
            label.textContent = labelText;
            div.appendChild(label);
        }
        
        var content = document.createElement('div');
        content.className = 'json-output';
        content.textContent = msg;
        div.appendChild(content);
        
        container.appendChild(div);
        container.scrollTop = container.scrollHeight;
    },

    _inputMsgTrim: function(historyCmds){
        var that = this;
        var inputMsg = document.getElementById('inputMsg');
        var msg = inputMsg.value.replace(/\n/g, '');
        if (msg == '') { inputMsg.focus(); return null; }
        historyCmds.push(msg);
        that._displayNewMsg("historyMsg", msg, "myMsg", "▶ 命令");
        var result = { cmdType : "cmd", data : {} };
        if(that._isJson(msg)){
            result.cmdType = "json";
            result.data = JSON.stringify({ data : JSON.parse(msg) });
        } else {
            result.data = JSON.stringify({ data : msg });
        }
        return result;
    },

    _sendCommand: function(historyCmds) {
        var that = this;
        var result = that._inputMsgTrim(historyCmds);
        if(!result){
            that._displayNewMsg("historyMsg", "命令不能为空", "errMsg", "✘ 错误");
            return;
        }
        var url = result.cmdType == "cmd" ? "/command" : "/message";
        
        fetch(url, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: result.data
        })
        .then(function(r) { return r.json(); })
        .then(function(res) {
            if (res.code != 0) {
                var errText = res.msg || '';
                if (typeof(res.msg) == "object") {
                    errText = JSON.stringify(res.msg, null, "  ");
                }
                that._displayNewMsg("historyMsg", "code=" + res.code + "\n" + errText, "errMsg", "✘ 错误返回");
                return;
            }
            var r = res.msg;
            var text = typeof(r) == "object" ? JSON.stringify(r, null, "  ") : String(r);
            that._displayNewMsg("historyMsg", text, "newMsg", "✔ 返回结果");
        })
        .catch(function(err) {
            that._displayNewMsg("historyMsg", String(err), "errMsg", "✘ 请求失败");
        });
        
        inputMsg.value = "";
        inputMsg.focus();
    },
};
</script>
</body>
</html>
]]
