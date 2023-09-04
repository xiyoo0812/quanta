#pragma once

#include <curl/curl.h>
#include "lua_kit.h"

using namespace std;

namespace lcurl {

    static size_t write_callback(char* buffer, size_t block_size, size_t count, void* arg);

    class curl_request
    {
    public:
        curl_request(CURLM* cm, CURL* c) : curl(c), curlm(cm) {}
        ~curl_request() {
            if (curl) {
                curl_multi_remove_handle(curlm, curl);
                curl_easy_cleanup(curl);
                curl = nullptr;
            }
            if (header) {
                curl_slist_free_all(header);
                header = nullptr;
            }
            curlm = nullptr;
        }

        void create(string_view url, size_t timeout_ms) {
            curl_easy_setopt(curl, CURLOPT_URL, url.data());
            curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1);
            curl_easy_setopt(curl, CURLOPT_WRITEDATA, (void*)this);
            curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, error);
            curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, timeout_ms);
            curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout_ms);
            curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, write_callback);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, false);
            curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, false);
            curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 1L);
        }

        bool call_get(string_view data) {
            return request(data);
        }

        bool call_post(string_view data) {
            curl_easy_setopt(curl, CURLOPT_POST, 1L);
            return request(data, true);
        }

        bool call_put(string_view data) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "PUT");
            return request(data, true);
        }

        bool call_del(string_view data) {
            curl_easy_setopt(curl, CURLOPT_CUSTOMREQUEST, "DELETE");
            return request(data);
        }

        void set_header(string_view value) {
            header = curl_slist_append(header, value.data());
        }

        int get_respond(lua_State* L) {
            long code = 0;
            luakit::kit_state kit_state(L);
            curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &code);
            return luakit::variadic_return(L, content, code, error);
        }

    private:
        bool request(string_view& data, bool body_field = false) {
            if (header) {
                curl_easy_setopt(curl, CURLOPT_HTTPHEADER, header);
            }
            int len = data.size();
            if (body_field || len > 0) {
                curl_easy_setopt(curl, CURLOPT_POSTFIELDS, data.data());
                curl_easy_setopt(curl, CURLOPT_POSTFIELDSIZE, len);
            }
            if (curl_multi_add_handle(curlm, curl) == CURLM_OK) {
                return true;
            }
            return false;
        }

    public:
        string content;

    private:
        CURL* curl = nullptr;
        CURLM* curlm = nullptr;
        curl_slist* header = nullptr;
        char error[CURL_ERROR_SIZE] = {};
    };

    class curlm_mgr
    {
    public:
        curlm_mgr(CURLM* cm, CURL* ce) : curle(ce), curlm(cm) {}

        void destory() {
            if (curle) {
                curl_easy_cleanup(curle);
                curle = nullptr;
            }
            if (curlm) {
                curl_multi_cleanup(curlm);
                curlm = nullptr;
            }
            curl_global_cleanup();
        }

        int create_request(lua_State* L, string_view url, size_t timeout_ms) {
            CURL* curl = curl_easy_init();
            if (!curl) {
                return 0;
            }
            curl_request* request = new curl_request(curlm, curl);
            request->create(url, timeout_ms);
            return luakit::variadic_return(L, request, curl);
        }

        int update(lua_State* L) {
            int running_handles;
            CURLMcode result = curl_multi_perform(curlm, &running_handles);
            if (result != CURLM_OK && result != CURLM_CALL_MULTI_PERFORM) {
                lua_pushboolean(L, false);
                lua_pushstring(L, "curl_multi_perform failed");
                return 2;
            }
            int msgs_in_queue;
            CURLMsg* curlmsg = nullptr;
            luakit::kit_state kit_state(L);
            while ((curlmsg = curl_multi_info_read(curlm, &msgs_in_queue)) != nullptr) {
                if (curlmsg->msg == CURLMSG_DONE){
                    kit_state.object_call(this, "on_respond", nullptr, tie(), curlmsg->easy_handle, curlmsg->data.result);
                    curl_multi_remove_handle(curlm, curlmsg->easy_handle);
                }
            }
            lua_pushboolean(L, true);
            return 1;
        }

    private:
        CURL* curle = nullptr;
        CURLM* curlm = nullptr;
    };

    static size_t write_callback(char* buffer, size_t block_size, size_t count, void* arg) {
        size_t length = block_size * count;
        curl_request* request = (curl_request*)arg;
        if (request) {
            request->content.append(buffer, length);
        }
        return length;
    }

}
