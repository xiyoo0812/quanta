#pragma once

#include <map>
#include <set>
#include <array>
#include <vector>
#include <chrono>
#include <thread>
#include <fstream>
#include <iostream>
#include <shared_mutex>
#include <assert.h>

#include "lua_kit.h"

#ifdef WIN32
#define NOMINMAX
#define getpid _getpid
#else
#include <unistd.h>
#endif

using namespace luakit;
using namespace std::chrono;
using namespace std::filesystem;

using fspath    = std::filesystem::path;

template <class T>
using wptr      = std::weak_ptr<T>;
template <class T>
using sptr      = std::shared_ptr<T>;

using log_time  = system_clock::time_point;

typedef void (*custom_output)(const char* msg, size_t len, int level);

namespace logger {
    enum class log_level : uint8_t {
        LOG_DEBUG = 1,
        LOG_INFO,
        LOG_WARN,
        LOG_DUMP,
        LOG_ERROR,
        LOG_FATAL,
    };
    using enum log_level;

    enum class rolling_type : uint8_t {
        HOURLY = 0,
        DAILY = 1,
    }; //rolling_type
    using enum rolling_type;

    const size_t QUEUE_SIZE = 2048;
    const size_t MAX_LINE   = 100000;

    constexpr auto level_names = std::array{"UNKNW", "DEBUG", "INFO", "WARN", "DUMP", "ERROR", "FATAL"};
    constexpr auto level_colors = std::array{"\x1b[90m", "\x1b[37m", "\x1b[32m", "\x1b[33m", "\x1b[36m", "\x1b[31m", "\x1b[97;41m"};

    class log_message {
    public:
        vstring data() const { return msg_; }
        size_t level() const { return (size_t)level_; }
        const vstring feature() const { return feature_; }
        void option(log_level lvl, sstring&& msg, cpchar tag, cpchar feature, cpchar trace_id);
        void format(pchar secbuf, seconds& last);

    private:
        log_time    time_;
        sstring     trace_id_, feature_, tag_;
        log_level   level_ = LOG_DEBUG;
        char*       large_ = nullptr;
        sstring     msg_;
    }; // class log_message

    class log_message_queue {
    public:
        log_message* pop();
        log_message* allocate();
        void commit();
        size_t size() const;
        bool empty() const;
        bool full() const;
    private:
        std::atomic<size_t>     head_ = 0;
        std::atomic<size_t>     tail_ = 0;
        log_message             msgs_[QUEUE_SIZE];
    }; // class log_message_queue

    class log_dest {
    public:
        virtual ~log_dest() = default;
        virtual void write(log_message* msg);
        virtual void raw_write(log_message* msg) = 0;
        virtual void set_custom_output(custom_output fn) { output_ = fn; }
        virtual void flush(){ };

    protected:
        size_t line_ = 0;
        custom_output output_ = nullptr;
    }; // class log_dest

    class stdio_dest : public log_dest {
    public:
        virtual void raw_write(log_message* msg);
    }; // class stdio_dest

    class log_file_base : public log_dest {
    public:
        log_file_base(size_t max_line) : max_line_(max_line) {
            file_time_ = system_clock::now();
        }
        virtual ~log_file_base();

        virtual void flush();
        virtual void raw_write(log_message* msg);
        void create(fspath file_path, sstring file_name);

    protected:
        log_time    file_time_;
        size_t      size_ = 0;
        size_t      max_line_ = MAX_LINE;
        char        log_buf_[USHRT_MAX] = { 0 };
        std::unique_ptr<std::ofstream> file_ = nullptr;
    }; // class log_file

    class rolling_hourly {
    public:
        bool eval(const log_time& filetime, const log_time& logtime) const;
    }; // class rolling_hourly

    class rolling_daily {
    public:
        bool eval(const log_time& filetime, const log_time& logtime) const;
    }; // class rolling_daily

    template<class rolling_evaler>
    class log_rollingfile : public log_file_base {
    public:
        log_rollingfile(fspath& log_path, vstring feature, size_t max_line = MAX_LINE);
        virtual void flush();

    protected:
        sstring new_log_file_name(const log_time& time);

        fspath                  log_path_;
        sstring                 feature_;
        rolling_evaler          rolling_evaler_;
    }; // class log_rollingfile

    typedef log_rollingfile<rolling_hourly> log_hourlyrollingfile;
    typedef log_rollingfile<rolling_daily> log_dailyrollingfile;

    class log_service;
    class log_agent {
    public:
        log_agent();
        ~log_agent();
        void filter(log_level lv, bool on);
        void attach(wptr<log_service> service);
        bool is_filter(log_level lv) { return 0 == (filter_bits_ & (1 << ((int)lv - 1))); }
        void output(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar trace_id);
        bool empty() const { return logmsgque_->empty(); }
        log_message* get_message();

    protected:
        char time_buf_[32] = {0};
        int32_t filter_bits_ = -1;
        wptr<log_service> service_;
        seconds last_time_ = seconds(0);
        sptr<log_message_queue> logmsgque_ = nullptr;
    }; // class log_agent

    class log_service : public std::enable_shared_from_this<log_service> {
    public:
        log_service();
        ~log_service();

        void daemon(bool status) { log_std_ = !status; }
        bool option(fspath log_path, cpchar service, cpchar index);

        bool add_dest(cpchar feature);
        bool add_lvl_dest(size_t log_lvl);
        bool add_file_dest(cpchar feature, cpchar fname);

        void del_dest(cpchar feature);
        void del_lvl_dest(size_t log_lvl);

        void del_agent(log_agent* agent);
        void add_agent(log_agent* agent);

        void set_max_line(size_t max_line) { max_line_ = max_line; }
        void set_rolling_type(rolling_type type) { rolling_type_ = type; }
        void set_custom_output(custom_output fn) { std_dest_->set_custom_output(fn); }
        void notify_one() { cv_.notify_one(); }

    protected:
        fspath build_path(cpchar feature);
        void run(std::stop_token stoken);
        void flush();

        fspath          log_path_;
        std::mutex      cvmutex_;
        std::shared_mutex mutex_;
        std::jthread    thread_;
        sstring         service_;
        sptr<log_dest>  std_dest_ = nullptr;
        sptr<log_dest>  main_dest_ = nullptr;
        std::set<log_agent*> agents_;
        std::condition_variable cv_;
        std::map<size_t, sptr<log_dest>> dest_lvls_;
        std::map<sstring, sptr<log_dest>, std::less<>> dest_features_;
        rolling_type rolling_type_ = DAILY;
        size_t max_line_ = MAX_LINE;
        bool log_std_ = true;
        bool running_ = true;
    }; // class log_service
}
