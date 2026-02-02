
#pragma once
#include <map>

#include "lua_kit.h"

using namespace std;
using namespace luakit;

inline char fromhex(unsigned char x) {
    if (x >= 'A' && x <= 'Z') return x - 'A' + 10;
    else if (x >= 'a' && x <= 'z') return x - 'a' + 10;
    else if (x >= '0' && x <= '9') return x - '0';
    else return x;
}

#include "url.h"
#include "guid.h"
#include "hash.h"
#include "http.h"
#include "http2.h"
#include "redis.h"
#include "mysql.h"
#include "pgsql.h"
#include "bitset.h"
#include "websocket.h"
