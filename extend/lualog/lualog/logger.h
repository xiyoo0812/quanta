#pragma once

#include <map>
#include <set>
#include <array>
#include <vector>
#include <chrono>
#include <thread>
#include <fstream>
#include <iostream>
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

    const size_t QUEUE_SIZE = 3000;
    const size_t MAX_LINE   = 100000;

    constexpr auto level_names = std::array{"UNKNW", "DEBUG", "INFO", "WARN", "DUMP", "ERROR", "FATAL"};
    constexpr auto level_colors = std::array{"\x1b[90m", "\x1b[37m", "\x1b[32m", "\x1b[33m", "\x1b[36m", "\x1b[31m", "\x1b[97;41m"};

    class log_message {
    public:
        log_level level() const { return level_; }
        const vstring feature() const { return feature_; }
        void option(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int32_t line);
        sstring format(bool prefix, bool suffix, bool crcn);
        void prepare(pchar secbuf, seconds& last);

    private:
        log_time    time_;
        log_level   level_ = LOG_DEBUG;
        sstring     msg_, feature_, tag_, prefix_, suffix_;
    }; // class log_message
    typedef std::vector<sptr<log_message>> log_messages;

    class log_message_pool {
    public:
        sptr<log_message> allocate();
        void recycle(sptr<log_messages> logmsgs);
    private:
        spin_mutex mutex_;
        sptr<log_messages> free_msgs_ = std::make_shared<log_messages>();
        sptr<log_messages> alloc_msgs_ = std::make_shared<log_messages>();
    }; // class log_message_pool

    class log_message_queue {
    public:
        void put(sptr<log_message> logmsg);
        sptr<log_messages> timed_getv(bool running);
    private:
        spin_mutex mutex_;
        sptr<log_messages> read_msgs_ = std::make_shared<log_messages>();
        sptr<log_messages> write_msgs_ = std::make_shared<log_messages>();
    }; // class log_message_queue

    class log_dest {
    public:
        virtual ~log_dest() = default;
        virtual bool crcn() { return true; }
        virtual void write(sptr<log_message> logmsg);
        virtual void raw_write(vstring logtxt, log_level lvl) = 0;
        virtual void ignore_prefix(bool prefix) { prefix_ = !prefix; }
        virtual void ignore_suffix(bool suffix) { suffix_ = !suffix; }
        virtual void set_custom_output(custom_output fn) { output_ = fn; }
        virtual void flush(){ };

    protected:
        size_t line_ = 0;
        bool prefix_ = true;
        bool suffix_ = false;
        custom_output output_ = nullptr;
    }; // class log_dest

    class stdio_dest : public log_dest {
    public:
        virtual bool crcn() { return false; }
        virtual void raw_write(vstring logtxt, log_level lvl);
    }; // class stdio_dest

    class log_file_base : public log_dest {
    public:
        log_file_base(size_t max_line) : max_line_(max_line) {
            file_time_ = system_clock::now();
        }
        virtual ~log_file_base();

        virtual void flush();
        virtual void raw_write(vstring logtxt, log_level lvl);
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
        void recycle(sptr<log_messages> logmsgs) { message_pool_->recycle(logmsgs); }
        bool is_filter(log_level lv) { return 0 == (filter_bits_ & (1 << ((int)lv - 1))); }
        sptr<log_messages> timed_getv(bool running) {  return logmsgque_->timed_getv(running); }
        void output(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source = "", int line = 0);

    protected:
        int32_t filter_bits_ = -1;
        wptr<log_service> service_;
        sptr<log_message_queue> logmsgque_ = nullptr;
        sptr<log_message_pool> message_pool_ = nullptr;
    }; // class log_agent

    class log_service : public std::enable_shared_from_this<log_service> {
    public:
        log_service();
        ~log_service();

        void daemon(bool status) { log_std_ = !status; }
        bool option(fspath log_path, cpchar service, cpchar index);

        bool add_dest(cpchar feature);
        bool add_lvl_dest(log_level log_lvl);
        bool add_file_dest(cpchar feature, cpchar fname);

        void del_dest(cpchar feature);
        void del_lvl_dest(log_level log_lvl);

        void del_agent(log_agent* agent);
        void add_agent(log_agent* agent);

        void ignore_prefix(cpchar feature, bool prefix);
        void ignore_suffix(cpchar feature, bool suffix);

        void set_max_line(size_t max_line) { max_line_ = max_line; }
        void set_rolling_type(rolling_type type) { rolling_type_ = type; }
        void set_custom_output(custom_output fn) { std_dest_->set_custom_output(fn); }

    protected:
        fspath build_path(cpchar feature);
        void run(std::stop_token stoken);
        void flush();

        fspath          log_path_;
        spin_mutex      mutex_;
        std::jthread    thread_;
        sstring         service_;
        sptr<log_dest>  std_dest_ = nullptr;
        sptr<log_dest>  main_dest_ = nullptr;
        std::set<log_agent*> agents_;
        std::map<log_level, sptr<log_dest>> dest_lvls_;
        std::map<sstring, sptr<log_dest>, std::less<>> dest_features_;
        rolling_type rolling_type_ = DAILY;
        size_t max_line_ = MAX_LINE;
        seconds last_time_ = seconds(0);
        char time_buf_[32] = {0};
        bool log_std_ = true;
        bool running_ = true;
    }; // class log_service
}
