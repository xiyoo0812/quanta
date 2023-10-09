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