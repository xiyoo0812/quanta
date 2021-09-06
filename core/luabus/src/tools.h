/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2016/10/19, trumanzhao@foxmail.com
*/

#pragma once

#ifdef _MSC_VER
#include <time.h>
#include <direct.h>
using int64_t = long long;
using uint64_t = unsigned long long;
#define getcwd _getcwd
#ifndef strdup
#define strdup _strdup
#endif
#define tzset _tzset
#endif

#if defined(__linux) || defined(__APPLE__)
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <netdb.h>
#include <sys/stat.h>
using BYTE = unsigned char;
#endif

#include <string.h>
#include <string>
#include <chrono>
#include <thread>

inline int64_t get_time_ns() { return std::chrono::high_resolution_clock::now().time_since_epoch().count(); }
inline int64_t get_time_ms() { return get_time_ns() / 1000 / 1000; }
inline void sleep_ms(int ms) { std::this_thread::sleep_for(std::chrono::milliseconds(ms)); }

time_t get_file_time(const char* file_name);

template <int N>
void safe_cpy(char (&buffer)[N], const char* str)
{
    if (str == nullptr)
    {
        buffer[0] = 0;
        return;
    }

	strncpy(buffer, str, N);
    buffer[N - 1] = 0;
}

#ifdef _MSC_VER
inline struct tm* localtime_r(const time_t* timep, struct tm* result)
{
    errno_t nErr = localtime_s(result, timep);
    return (nErr == 0) ? result : nullptr;
}
#endif

#ifdef _MSC_VER
inline bool make_dir(const char cszDir[]) { return (_mkdir(cszDir) != -1); }
#endif

#if defined(__linux) || defined(__APPLE__)
inline bool make_dir(const char cszDir[]) { return (mkdir(cszDir, 0777) != -1); }
#endif


#ifdef _MSC_VER
inline uint64_t get_thread_id() { return GetCurrentThreadId(); }
#endif

#if defined(__linux) || defined(__APPLE__)
inline uint64_t get_thread_id() { return (uint64_t)pthread_self(); }
#endif


#define FAILED_JUMP(C)  \
    do  \
    {   \
        if (!(C)) goto Exit0; \
    } while (0)

#define SAFE_FREE(p)    \
    do  \
    {   \
        if (p)  \
        {   \
            free(p);    \
            (p) = nullptr;  \
        }   \
    } while (0)

#define SAFE_DELETE(p)  \
    do  \
    {   \
        if (p)  \
        {   \
            delete (p);    \
            (p) = nullptr;  \
        }   \
    } while (0)

#define SAFE_DELETE_ARRAY(p)    \
    do  \
    {   \
        if (p)  \
        {   \
            delete[] (p);    \
            (p) = nullptr;  \
        }   \
    } while (0)

#define SAFE_RELEASE(p) \
    do  \
    {   \
        if (p)  \
        {   \
            (p)->release();    \
            (p) = nullptr;  \
        }   \
    } while (0)


#if defined(__linux) || defined(__APPLE__)
template <typename T, int N>
constexpr int _countof(T(&_array)[N]) { return N; }
#endif

#define MAX_ERROR_TXT 128

char* get_error_string(char buffer[], int len, int no);
void get_error_string(std::string& err, int no);
