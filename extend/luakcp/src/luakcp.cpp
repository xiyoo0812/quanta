#define LUA_LIB

#ifdef _MSC_VER
#include <Ws2tcpip.h>
#include <windows.h>
#pragma comment(lib, "Ws2_32.lib")
inline int get_socket_error() { return WSAGetLastError(); }
#endif
#if defined(__linux) || defined(__APPLE__)
#include <fcntl.h>
#include <errno.h>
#include <unistd.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/udp.h>
#define WSAEWOULDBLOCK EWOULDBLOCK
typedef struct sockaddr SOCKADDR;
typedef struct sockaddr_in SOCKADDR_IN;
inline void closesocket(int fd) { close(fd); }
inline int get_socket_error() { return errno; }
#endif

#include "ikcp.h"

#include "lua_kit.h"

using namespace std;
using namespace luakit;

#define KCP_CONV  10131025

namespace luakcp {
    enum class link_status : uint8_t {
        LINK_INIT       = 0,
        LINK_READY      = 1,
        LINK_CLOSED     = 2,
    };
    using enum link_status;

    void set_no_block(int fd) {
#ifdef _MSC_VER
        u_long  opt = 1;
        ioctlsocket(fd, FIONBIO, &opt);
#else
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL, 0) | O_NONBLOCK);
#endif
    }

    inline char* alloc_buff(size_t sz) {
        auto buf = luakit::get_buff();
        return (char*)buf->peek_space(sz);
    }

    class kcp_socket;
    struct ikcp_mgr {
        virtual kcp_socket* on_accept(const char* ip, int port) = 0;
    };
    class kcp_socket {
    public:
        ~kcp_socket() {
            if (m_lvm) {
                delete m_lvm;
                m_lvm = nullptr;
            }
            if (m_kcp) {
                ikcp_release(m_kcp);
                m_kcp = nullptr;
            }
            if (m_fd > 0) {
                closesocket(m_fd);
                m_fd = 0;
            }
        }

        void __gc() {}
        void close() {
            m_status = LINK_CLOSED;
        }

        void set_codec(codec_base* codec) {
            m_codec = codec;
        }
        
        void set_timeout(uint32_t to) {
            m_timeout = to;
        }

        bool setup(lua_State* L, int token, ikcp_mgr* mgr = nullptr) {
            int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
            if (fd <= 0) return false;
            ikcpcb* kcp = ikcp_create(KCP_CONV, (void*)this);
            if (kcp == nullptr) return false;
            ikcp_setoutput(kcp, kcp_callback);
            set_no_block(fd);
            m_lvm = new kit_state(L);
            m_token = token;
            m_mgr = mgr;
            m_kcp = kcp;
            m_fd = fd;
            return true;
        }

        bool listen(const char* ip, int port) {
            auto ok = bind(inet_addr(ip), port);
            if (ok) m_status = LINK_READY;
            return ok;
        }

        bool connect(const char* ip, int port) {
            auto ok = bind(INADDR_ANY, port);
            if (!ok) return false;
            m_status = LINK_READY;
            m_port = port;
            m_ip = ip;
            return true;
        }

        bool update(uint64_t time) {
            if (m_status == LINK_CLOSED) return false;
            if (m_timeout > 0 && m_livetime > 0 && time - m_livetime > m_timeout) {
                on_error("kcp timeout");
                return true;
            }
            ikcp_update(m_kcp, time);
            udp_recv(time);
            return true;
        }
        
        int send_kcp(lua_State* L) {
            if (m_codec) {
                size_t data_len = 0;
                char* data = (char*)m_codec->encode(L, 1, &data_len);
                if (data && data_len <= USHRT_MAX && ikcp_send(m_kcp, data, data_len) > 0) {
                    lua_pushinteger(L, data_len);
                    return 1;
                }
            }
            lua_pushinteger(L, 0);
            return 1;
        }

        static int kcp_callback(const char* buf, int len, ikcpcb* kcp, void* arg) {
            kcp_socket* skcp = (kcp_socket*)arg;
            skcp->udp_send(buf, len);
            return 0;
        }

    protected:
        bool bind(size_t ipaddr, int port) {
            SOCKADDR_IN addr = {};
            addr.sin_family = AF_INET;
            addr.sin_port = htons(port);
            addr.sin_addr.s_addr = ipaddr;
            return ::bind(m_fd, (SOCKADDR*)&addr, sizeof(addr)) == 0;
        }

        void udp_send(const char* data, size_t data_len) {
            SOCKADDR_IN addr = {};
            addr.sin_family = AF_INET;
            addr.sin_port = htons(m_port);
            addr.sin_addr.s_addr = inet_addr(m_ip.c_str());
            int send_len = sendto(m_fd, data, data_len, 0, (SOCKADDR*)&addr, sizeof(addr));
            if (send_len < 0) {
                on_error("udp sendto failed!");
            }
        }

        void udp_recv(uint64_t time) {
            SOCKADDR_IN addr = {};
            char* buf = alloc_buff(USHRT_MAX);
            socklen_t nlen = (socklen_t)sizeof(addr);
            int recv_len = recvfrom(m_fd, buf, USHRT_MAX, 0, (SOCKADDR*)&addr, &nlen);
            if (recv_len <= 0) {
                auto errcode = get_socket_error();
                if (errcode == WSAEWOULDBLOCK || errcode == 10054) {
                    return;
                }
                on_error("udp recvfrom failed!");
                return;
            }
            m_livetime = time;
            auto ip = inet_ntoa(addr.sin_addr);
            int port = ntohs(addr.sin_port);
            if (ikcp_input(m_kcp, buf, recv_len) < 0) {
                on_error("kcp input failed!");
                return;
            }
            kcp_recv(time, ip, port);
        }

        void kcp_recv(uint64_t time, const char* ip, int port) {
            char* buf = alloc_buff(USHRT_MAX);
            int32_t recv_size = ikcp_recv(m_kcp, buf, USHRT_MAX);
            if (recv_size < 0) {
                //EAGAIN
                if (recv_size == -1) return;
                on_error("kcp recv failed!");
                return;
            }
            if (!m_mgr) {
                on_recv(buf, recv_size, ip, port);
                return;
            }
            auto skcp = m_mgr->on_accept(ip, port);
            if (skcp) {
                swap_kcp(skcp);
                skcp->m_livetime = time;
                m_lvm->object_call(this, "on_accept", nullptr, std::tie(), skcp);
                skcp->on_recv(buf, recv_size, ip, port);
            }
        }

        void swap_kcp(kcp_socket* skcp) {
            swap(skcp->m_kcp, m_kcp);
            skcp->m_kcp->user = skcp;
            m_kcp->user = this;
        }
        
        void on_recv(const char* data, size_t data_len, const char* ip, size_t port) {
            m_ip = ip;
            m_port = port;
            slice sli((uint8_t*)data, data_len);
            m_codec->set_slice(&sli);
            m_lvm->object_call(this, "on_call", nullptr, m_codec, std::tie());
        }

        void on_error(std::string_view err) {
            m_lvm->object_call(this, "on_error", nullptr, std::tie(), m_token, err);
            m_status = LINK_CLOSED;
        }

    public:
        int m_port = 0;
        int m_token = 0;
        std::string m_ip = "";

    protected:
        int m_fd = 0;
        uint32_t m_timeout = 0;
        uint64_t m_livetime = 0;
        ikcpcb* m_kcp = nullptr;
        ikcp_mgr* m_mgr = nullptr;
        kit_state* m_lvm = nullptr;
        codec_base* m_codec = nullptr;
        link_status m_status = LINK_INIT;
    };

    class kcp_mgr :public ikcp_mgr {
    public:
        void setup(lua_State* L) {
            m_lvm = L;
        }

        int update(int32_t now) {
            auto it = m_kcps.begin(), end = m_kcps.end();
            while (it != end) {
                kcp_socket* kcp = it->second;
                if (!kcp->update(now)) {
                    it = m_kcps.erase(it);
                    delete kcp;
                    continue;
                }
                ++it;
            }
            return 0;
        }

        void close(uint32_t token) {
            if (auto kcp = get_kcp(token); kcp) {
                kcp->close();
            }
        }

        kcp_socket* listen(const char* ip, int port) {
            uint32_t token = new_token();
            kcp_socket* kcp = new kcp_socket();
            if (!kcp->setup(m_lvm, token, this) || !kcp->listen(ip, port)) {
                delete kcp;
                return nullptr;
            }
            m_kcps.insert(std::make_pair(token, kcp));
            return kcp;
        }

        kcp_socket* connect(const char* ip, int port) {
            uint32_t token = new_token();
            kcp_socket* kcp = new kcp_socket();
            if (!kcp->setup(m_lvm, token) || !kcp->connect(ip, port)) {
                delete kcp;
                return nullptr;
            }
            m_kcps.insert(std::make_pair(token, kcp));
            return kcp;
        }

        kcp_socket* on_accept(const char* ip, int port) {
            uint32_t token = new_token();
            kcp_socket* kcp = new kcp_socket();
            if (!kcp->setup(m_lvm, token) || !kcp->connect(ip, port)) {
                delete kcp;
                return nullptr;
            }
            m_kcps.insert(std::make_pair(token, kcp));
            return kcp;
        }
        
    protected:
        kcp_socket* get_kcp(int token) {
            auto it = m_kcps.find(token);
            if (it != m_kcps.end()) {
                return it->second;
            }
            return nullptr;
        }

        uint32_t new_token() {
            while (++m_token == 0 || m_kcps.contains(m_token)) {}
            return m_token;
        }

    protected:
        uint32_t m_token = 0;
        lua_State* m_lvm = nullptr;
        std::unordered_map<uint32_t, kcp_socket*> m_kcps;
    };
    
    thread_local kcp_mgr kmgr;
    luakit::lua_table open_luakcp(lua_State* L) {
        luakit::kit_state kit_state(L);
        kit_state.new_class<kcp_socket>(
            "ip", &kcp_socket::m_ip,
            "port", &kcp_socket::m_port,
            "token", &kcp_socket::m_token,
            "close", &kcp_socket::close,
            "send_kcp", &kcp_socket::send_kcp,
            "set_codec", &kcp_socket::set_codec,
            "set_timeout", &kcp_socket::set_timeout
        );
        kmgr.setup(L);
        auto lkcp = kit_state.new_table("kcp");
        lkcp.set_function("connect", [](const char* ip, int port) { return kmgr.connect(ip, port); });
        lkcp.set_function("listen", [](const char* ip, int port) { return kmgr.listen(ip, port); });
        lkcp.set_function("close", [](uint32_t token) { return kmgr.close(token); });
        lkcp.set_function("update", [](int32_t now) { return kmgr.update(now); });
        return lkcp;
    }
}

extern "C" {
    LUALIB_API int luaopen_luakcp(lua_State* L) {
        auto lkcp = luakcp::open_luakcp(L);
        return lkcp.push_stack();
    }
}