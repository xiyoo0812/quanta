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