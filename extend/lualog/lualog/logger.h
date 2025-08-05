#pragma once

#include <map>
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
#endif

using namespace luakit;
using namespace std::chrono;
using namespace std::filesystem;

using cpchar    = const char*;
using sstring   = std::string;
using vstring   = std::string_view;
using cstring   = const std::string;

template <class T>
using wptr      = std::weak_ptr<T>;
template <class T>
using sptr      = std::shared_ptr<T>;

using log_time  = time_point<system_clock, milliseconds>;
using zone_time = zoned_time<milliseconds, time_zone*>;

namespace logger {
    enum class log_level : uint8_t {
        LOG_LEVEL_DEBUG = 1,
        LOG_LEVEL_INFO,
        LOG_LEVEL_WARN,
        LOG_LEVEL_DUMP,
        LOG_LEVEL_ERROR,
        LOG_LEVEL_FATAL,
    };
    using enum log_level;

    enum class rolling_type : uint8_t {
        HOURLY = 0,
        DAYLY = 1,
    }; //rolling_type
    using enum rolling_type;

    const size_t QUEUE_SIZE = 3000;
    const size_t MAX_LINE   = 100000;
    const size_t CLEAN_TIME = 7 * 24 * 3600;

    constexpr auto level_names = std::array{"UNKNW", "DEBUG", "INFO", "WARN", "DUMP", "ERROR", "FATAL"};
    constexpr auto level_colors = std::array{"\x1b[32m", "\x1b[37m", "\x1b[32m", "\x1b[33m", "\x1b[33m", "\x1b[31m", "\x1b[32m"};

    class log_message {
    public:
        log_level level() const { return level_; }
        vstring feature() const { return feature_; }
        void option(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int32_t line);
        sstring format(bool prefix, bool suffix, bool clr = false);
        zone_time prepare(time_zone* zone);

    private:
        log_time            time_;
        log_level           level_ = LOG_LEVEL_DEBUG;
        sstring             msg_, feature_, tag_, prefix_, suffix_;
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
        virtual bool color() { return false; }
        virtual void flush(const zone_time& time) = 0;
        virtual void raw_write(vstring logtxt, size_t size) = 0;
        virtual void write(sptr<log_message> logmsg, const zone_time& logtime);
        virtual void ignore_prefix(bool prefix) { prefix_ = !prefix; }
        virtual void ignore_suffix(bool suffix) { suffix_ = !suffix; }
        virtual void set_clean_time(size_t clean_time) {}

    protected:
        size_t size_ = 0;
        size_t line_ = 0;
        bool prefix_ = true;
        bool suffix_ = false;
        char log_buf_[USHRT_MAX] = {0};
    }; // class log_dest

    class stdio_dest : public log_dest {
    public:
        virtual bool color();
        virtual void flush(const zone_time& time);
        virtual void raw_write(vstring logtxt, size_t size);
    }; // class stdio_dest

    class log_file_base : public log_dest {
    public:
        log_file_base(size_t max_line, const zone_time& time) : max_line_(max_line), file_time_(time.get_local_time()){}
        virtual ~log_file_base();

        virtual void flush(const zone_time& time);
        virtual void raw_write(vstring logtxt, size_t size);
        void create(path file_path, sstring file_name);

    protected:
        size_t                      max_line_;
        local_time<microseconds>    file_time_;
        std::unique_ptr<std::ofstream> file_ = nullptr;
    }; // class log_file

    class rolling_hourly {
    public:
        bool eval(const local_time<microseconds>& filetime, const zone_time& logtime) const;
    }; // class rolling_hourly

    class rolling_daily {
    public:
        bool eval(const local_time <microseconds>& filetime, const zone_time& logtime) const;
    }; // class rolling_daily

    template<class rolling_evaler>
    class log_rollingfile : public log_file_base {
    public:
        log_rollingfile(path& log_path, const zone_time& time, vstring feature, size_t max_line = MAX_LINE, size_t clean_time = CLEAN_TIME);

        virtual void flush(const zone_time& time);
        virtual void set_clean_time(size_t clean_time) { clean_time_ = clean_time; }

    protected:
        sstring new_log_file_name(const zone_time& time);

        path                    log_path_;
        sstring                 feature_;
        rolling_evaler          rolling_evaler_;
        size_t                  clean_time_ = CLEAN_TIME;
    }; // class log_rollingfile

    typedef log_rollingfile<rolling_hourly> log_hourlyrollingfile;
    typedef log_rollingfile<rolling_daily> log_dailyrollingfile;

    class log_service;
    class log_agent : public std::enable_shared_from_this<log_agent> {
    public:
        log_agent();
        ~log_agent();
        uint32_t get_id();
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
        void option(cpchar log_path, cpchar service, cpchar index, cpchar zone);

        bool add_dest(cpchar feature);
        bool add_lvl_dest(log_level log_lvl);
        bool add_file_dest(cpchar feature, cpchar fname);

        void del_dest(cpchar feature);
        void del_lvl_dest(log_level log_lvl);

        void del_agent(uint32_t tid);
        void add_agent(sptr<log_agent> agent);

        void ignore_prefix(cpchar feature, bool prefix);
        void ignore_suffix(cpchar feature, bool suffix);

        void set_max_line(size_t max_line) { max_line_ = max_line; }
        void set_rolling_type(rolling_type type) { rolling_type_ = type; }
        void set_clean_time(size_t clean_time) { clean_time_ = clean_time; }
        void set_dest_clean_time(cpchar feature, size_t clean_time);

    protected:
        path build_path(cpchar feature);
        void run(std::stop_token stoken);
        void flush();

        path            log_path_;
        spin_mutex      mutex_;
        std::jthread    thread_;
        sstring         service_;
        time_zone*      zone_ = nullptr;
        sptr<log_dest>  std_dest_ = nullptr;
        sptr<log_dest>  main_dest_ = nullptr;
        std::map<uint64_t, sptr<log_agent>> agents_;
        std::map<log_level, sptr<log_dest>> dest_lvls_;
        std::map<sstring, sptr<log_dest>, std::less<>> dest_features_;
        size_t max_line_ = MAX_LINE, clean_time_ = CLEAN_TIME;
        rolling_type rolling_type_ = DAYLY;
        bool log_std_ = true;
        bool running_ = true;
    }; // class log_service
}

extern "C" {
    LUALIB_API void option_logger(cpchar log_path, cpchar service, cpchar index, cpchar zone = "Asia/Shanghai");
    LUALIB_API void output_logger(logger::log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int line);
}

#define LOG_WARN(msg) output_logger(logger::LOG_LEVEL_WARN, msg, "", "", __FILE__, __LINE__)
#define LOG_INFO(msg) output_logger(logger::LOG_LEVEL_INFO, msg, "", "", __FILE__, __LINE__)
#define LOG_DUMP(msg) output_logger(logger::LOG_LEVEL_DUMP, msg, "", "", __FILE__, __LINE__)
#define LOG_DEBUG(msg) output_logger(logger::LOG_LEVEL_DEBUG, msg, "", "", __FILE__, __LINE__)
#define LOG_ERROR(msg) output_logger(logger::LOG_LEVEL_ERROR, msg, "", "", __FILE__, __LINE__)
#define LOG_FATAL(msg) output_logger(logger::LOG_LEVEL_FATAL, msg, "", "", __FILE__, __LINE__)
#define LOGF_WARN(msg, feature) output_logger(logger::LOG_LEVEL_WARN, msg, "", feature, __FILE__, __LINE__)
#define LOGF_INFO(msg, feature) output_logger(logger::LOG_LEVEL_INFO, msg, "", feature, __FILE__, __LINE__)
#define LOGF_DUMP(msg, feature) output_logger(logger::LOG_LEVEL_DUMP, msg, "", feature, __FILE__, __LINE__)
#define LOGF_DEBUG(msg, feature) output_logger(logger::LOG_LEVEL_DEBUG, msg, "", feature, __FILE__, __LINE__)
#define LOGF_ERROR(msg, feature) output_logger(logger::LOG_LEVEL_ERROR, msg, "", feature, __FILE__, __LINE__)
#define LOGF_FATAL(msg, feature) output_logger(logger::LOG_LEVEL_FATAL, msg, "", feature, __FILE__, __LINE__)
#define LOGTF_WARN(msg, tag, feature) output_logger(logger::LOG_LEVEL_WARN, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_INFO(msg, tag, feature) output_logger(logger::LOG_LEVEL_INFO, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_DUMP(msg, tag, feature) output_logger(logger::LOG_LEVEL_DUMP, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_DEBUG(msg, tag, feature) output_logger(logger::LOG_LEVEL_DEBUG, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_ERROR(msg, tag, feature) output_logger(logger::LOG_LEVEL_ERROR, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_FATAL(msg, tag, feature) output_logger(logger::LOG_LEVEL_FATAL, msg, tag, feature, __FILE__, __LINE__)
