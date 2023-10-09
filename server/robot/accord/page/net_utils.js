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