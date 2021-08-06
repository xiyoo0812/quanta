/*
** repository: https://github.com/trumanzhao/luna
** trumanzhao, 2016/10/19, trumanzhao@foxmail.com
*/

#pragma once

#ifdef _WIN32
#include <time.h>
#include <direct.h>
using int64_t = long long;
using uint64_t = unsigned long long;
#define getcwd _getcwd
#define strdup _strdup
#define tzset _tzset
#endif

#if defined(__linux) || defined(__APPLE__)
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <netdb.h>
#include <sys/stat.h>
using BYTE = unsigned char;
#else
#include <windows.h>
#endif

#include <string>
#include <thread>

time_t get_file_time(const char* file_name);

inline const char* get_platform()
{
#if defined(__linux)
	return "linux";
#elif defined(__APPLE__)
	return "apple";
#else
	return "windows";
#endif
}

template <int N>
void safe_cpy(char (&buffer)[N], const char* str)
{
    if (str == nullptr)
    {
        buffer[0] = '\0';
        return;
    }

    strncpy(buffer, str, N);
    buffer[N - 1] = '\0';
}

#ifdef _WIN32
inline uint64_t get_thread_id() { return GetCurrentThreadId(); }
#endif

#if defined(__linux) || defined(__APPLE__)
inline uint64_t get_thread_id() { return (uint64_t)pthread_self(); }
#endif

#if defined(__linux) || defined(__APPLE__)
template <typename T, int N>
constexpr int _countof(T(&_array)[N]) { return N; }
#endif

#ifndef _WIN32
char *strupr(char *str);
#endif

#define MAX_ERROR_TXT 128

char* get_error_string(char buffer[], int len, int no);
void get_error_string(std::string& err, int no);

bool get_full_path(std::string& fullpath, const char* path);


