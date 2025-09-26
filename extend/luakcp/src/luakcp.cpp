#define LUA_LIB
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#ifdef _MSC_VER
#include <Winsock2.h>
#include <Ws2tcpip.h>
#include <mswsock.h>
#include <windows.h>
#pragma comment(lib, "Ws2_32.lib")
inline int get_socket_error() { return WSAGetLastError(); }
#endif
#if defined(__linux) || defined(__APPLE__)
#include <fcntl.h>
#include <errno.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netinet/in.h>
#include <netinet/udp.h>
typedef struct sockaddr SOCKADDR;
typedef struct sockaddr_in SOCKADDR_IN;
inline void closesocket(int fd) { close(fd); }
inline int get_socket_error() { return errno; }
#endif

#include "ikcp.h"

#include "luakit.h"

#define RECV_BUFF_LEN   64*1024

namespace luakcp {

    class kcp_mgr;
    class kcp_socket {
    public:
        ~kcp_socket() {
            if (m_kcp) {
                ikcp_release(m_kcp);
                m_kcp = nullptr;
            }
            if (m_fd > 0) {
                closesocket(fd);
                m_fd = 0;
            }
        }

        bool setup(kcp_mgr* mgr = nullptr) {
            int fd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
            if (fd <= 0) return false;
            m_token = new_token();
            if (m_mgr) {
                m_fd = fd;
                m_mgr = mgr;
                return true;
            }
            ikcpcb* kcp = ikcp_create(m_token, (void*)this);
            if (kcp == nullptr) return false;
            kcp->output = kcp_callback;
            m_kcp = kcp;
            m_fd = fd;
            return true;
        }

        bool listen(const char* ip, int port) {
            SOCKADDR_IN addr = {};
            addr.sin_family = AF_INET;
            addr.sin_port = htons(port);
            addr.sin_addr.s_addr = inet_addr(ip);
            if (bind(fd, (SOCKADDR*)&addr, sizeof(addr)) < 0) {
                closesocket(fd);
                return false;
            }
            return true;
        }

        bool connect(const char* ip, int port) {
            SOCKADDR_IN addr = {}
            addr.sin_family = AF_INET;
            addr.sin_port = htons(0);
            addr.sin_addr.s_addr = INADDR_ANY;
            if (bind(fd, (SOCKADDR*)&addr, sizeof(addr)) < 0) {
                closesocket(fd);
                return false;
            }
            m_ip = ip;
            m_port = port;
            return true;
        }

        bool accept(const char* ip, int port, const char* data, int data_len) {
            m_ip = ip;
            m_port = port;
            return kcp_input(data, data_len);
        }

        bool update(uint32_t time) {
            if (!udp_recv()) return false;
            if (!m_mgr) {
                ikcp_update(m_kcp, time);
                return kcp_recv();
            }
            return true;
        }
        
        int32_t send(const void* data, size_t data_len) {
            return ikcp_send(m_kcp, data, data_len);
        }

        static int kcp_callback(const char *buf, int len, ikcpcb *kcp, void *arg) {
            kcp_socket* skcp = (kcp_socket*)arg;
            skcp->udp_send(buf, len);
            return 0;
        }

    protected:
        void udp_send(const void* data, size_t data_len) {
            SOCKADDR_IN addr = {};
            addr.sin_family = AF_INET;
            addr.sin_port = htons(m_port);
            addr.sin_addr.s_addr = inet_addr(m_ip.c_str());
            sendto(m_fd, data, data_len, 0, (SOCKADDR*)&addr, sizeof(addr));
        }

        bool udp_recv() {
            SOCKADDR_IN addr = {};
            socklen_t nlen = (socklen_t)sizeof(addr);
            int recv_len = recvfrom(m_fd, buf, RECV_BUFF_LEN, 0, (SOCKADDR*)&addr, &nlen);
            if (recv_len <= 0) {
                on_error("udp recvfrom failed!");
                return false;
            }
            if (!m_mgr) {
                return kcp_input(buf, recv_len);
            }
            m_mgr->on_accept(inet_ntoa(addr.sin_addr), ntohs(addr.sin_port), data, data_len);
            return true;
        }

        bool kcp_input(buf, recv_len) {
             int32_t hr = ikcp_input(m_kcp, buf, recv_len);
            if (hr <= 0) {
                on_error("kcp input failed!");
                return false;
            }
            return true;
        }

        bool kcp_recv() {
            int32_t recv_size = ikcp_recv(m_kcp, buf, RECV_BUFF_LEN);
            if (recv_size <= 0) {
                on_error("kcp recv failed!");
                return false;
            }
            on_recv(buf, recv_size);
            return true
        }

        void on_recv(const char* buf, int len) {

        }
    
        void on_error(std::string_view err) {

        }
        
        static uint32_t new_token() {
            static uint32_t token = 0;
            while (++token == 0) {}
            return token;
        }

    protected:
        int m_fd = 0;
        int m_port = 0;
        std::string m_ip = "";
        ikcpcb* m_kcp = nullptr;
        kcp_mgr* m_mgr = nullptr;
    };

    class kcp_mgr {
    public:
        int wait(int32_t now) {
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
            auto it = m_kcps.find(token);
            if (it != m_kcps.end()) {
                delete it->second;
                m_kcps.erase(it);
            }
        }

        kcp_socket* listen(const char* ip, int port) {
            uint32_t token = new_token();
            kcp_socket* kcp = new kcp_socket();
            if (!kcp->setup(this) || !kcp->listen(ip, port)) {
                delete kcp;
                return nullptr;
            }
            m_kcps.insert(std::make_pair(token, kcp));
            return kcp;
        }

        kcp_socket* connect(const char* ip, int port) {
            uint32_t token = new_token();
            kcp_socket* kcp = new kcp_socket();
            if (!kcp->setup() || !kcp->connect(ip, port)) {
                delete kcp;
                return nullptr;
            }
            m_kcps.insert(std::make_pair(token, kcp));
            return kcp;
        }

        void on_accept(const char* ip, int port, const char* data, int data_len) {
            uint32_t token = new_token();
            kcp_socket* kcp = new kcp_socket();
            if (!kcp->setup() || !kcp->accept(ip, port, data, data_len)) {
                delete kcp;
                return nullptr;
            }
            m_kcps.insert(std::make_pair(token, kcp));
        }

        kcp_socket* get_kcp(int token) {
            auto it = m_kcps.find(token);
            if (it != m_kcps.end()) {
                return it->second;
            }
            return nullptr;
        }
        
    protected:
        uint32_t new_token() {
            while (++m_token == 0 || m_kcps.contains(m_token)) {}
            return m_token;
        }

    protected:
        uint32_t m_token = 0;
        std::unordered_map<uint32_t, kcp_socket*> m_kcps;
    };

}