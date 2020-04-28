#pragma once

#include "httplib.h"
#include <string.h>
#include <stdio.h>
#include <string>
#include <vector>

class url_fields
{
public:
    std::string url;
    std::string fullpath;
    std::string query;
    std::map <std::string, std::string > param;
    std::string verb;
    std::string prot;
    std::string host;
    int         port;
    std::string path;
    std::string file;
};

inline bool parse_url(std::string urlin, url_fields & out) {
    size_t i = 0;
    if (strcasecmp(urlin.substr(0, 4).c_str(), "http") != 0)
        return false;
    int lastpos = 0;
    int pos = 0;
    std::string childs[10];
    std::string temp;
    int idx = 0;
    out.url = urlin;
    // 查找‘?’
    out.fullpath = urlin;
    pos = urlin.find('?', 0);
    if (pos >= 0) {
        out.fullpath = urlin.substr(0, pos);
        out.query = urlin.substr(pos + 1);
    }
    // 分析query以 & 分割参数对，以=分割 k-v
    lastpos = 0;
    for (i = 0; i < out.query.length(); i++) {
        if (out.query[i] == '&') {
            temp = out.query.substr(lastpos, i - lastpos);
            pos = temp.find('=', 0);
            if (pos >= 0) {
                out.param[temp.substr(0, pos)] = temp.substr(pos + 1);
            }
            lastpos = i + 1;
        }
    }
    temp = out.query.substr(lastpos);
    pos = temp.find('=', 0);
    if (pos >= 0) {
        out.param[temp.substr(0, pos)] = temp.substr(pos + 1);
    }
    lastpos = 0;
    idx = 0;
    for (i = 0; i < out.fullpath.length(); i++) {
        if (out.fullpath[i] == ':') {
            childs[idx] = out.fullpath.substr(lastpos, i - lastpos);
            lastpos = i + 1;
            idx++;
            break;
        }
    }
    out.prot = childs[0];
    if (out.prot == "http")
        out.port = 80;
    else
        out.port = 443;

    std::string fullpath = out.fullpath.substr(out.prot.length() + 3);
    pos = fullpath.find('/');
    if (pos >= 0) {
        out.host = fullpath.substr(0, pos);
        out.path = fullpath.substr(pos);
    }
    else if (pos = fullpath.find('\\') >= 0) {
        out.host = fullpath.substr(0, pos);
        out.path = fullpath.substr(pos);
    }
    pos = out.host.find(':');
    if (pos >= 0) {
        out.port = atoi(out.host.substr(pos + 1).c_str());
        out.host = out.host.substr(0, pos);
    }
    pos = out.path.rfind('/');
    if (pos >= 0) {
        out.file = out.path.substr(pos + 1);
    }
    else if (pos = out.path.rfind('\\') >= 0) {
        out.file = out.path.substr(pos + 1);
    }

    return true;
}

inline int http_request(const std::string& url, const std::string& method, const std::string& param,
    const httplib::Headers& headers, int32_t timeout, std::shared_ptr<httplib::Response>& response_sptr)
{
    response_sptr = NULL;
    // 解析url
    url_fields url_info;
    if (!parse_url(url, url_info))
        return -1;

    std::shared_ptr<httplib::Client> client_sptr = NULL;
    if (url_info.prot == "http")
    {
        client_sptr.reset(new httplib::Client(url_info.host, url_info.port));
    }
    else if (url_info.prot == "https")
    {
        auto ssl_client_ptr = new httplib::SSLClient(url_info.host, url_info.port);
        ssl_client_ptr->enable_server_certificate_verification(false);
        client_sptr.reset(ssl_client_ptr);
    }

    // protocol error
    if (NULL == client_sptr)
    {
        return -1;
    }

    // 允许重定向
    client_sptr->set_follow_location(true);
    // 设置超时
    //client_sptr->set_timeout_sec(timeout);      // connect超时
    //client_sptr->set_read_timeout(timeout, 0);  // recv超时


    if (method == "GET")
    {
        response_sptr = client_sptr->Get(url.c_str(), headers);
    }
    else if (method == "POST")
    {
        response_sptr = client_sptr->Post(url.c_str(), headers, param, "application/json");
    }

    // 请求错误
    if (response_sptr == NULL)
    {
        return -2;
    }

    return 0;
}