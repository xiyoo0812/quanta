#pragma once

#include <list>
#include <array>
#include <ctime>
#include <mutex>
#include <vector>
#include <chrono>
#include <atomic>
#include <thread>
#include <fstream>
#include <iostream>
#include <filesystem>
#include <unordered_map>
#include <condition_variable>
#include <assert.h>

#include "fmt/core.h"
#include "lua_kit.h"

#ifdef WIN32
#include <process.h>
#define getpid _getpid
#else
#include <unistd.h>
#endif

using namespace std::chrono;
using namespace std::filesystem;

namespace logger {
    enum class log_level {
        LOG_LEVEL_DEBUG = 1,
        LOG_LEVEL_INFO,
        LOG_LEVEL_WARN,
        LOG_LEVEL_ERROR,
        LOG_LEVEL_FATAL,
        LOG_LEVEL_DUMP,
    };

    enum class rolling_type {
        HOURLY = 0,
        DAYLY = 1,
    }; //rolling_type

    const size_t QUEUE_MINI = 10;
    const size_t QUEUE_SIZE = 3000;
    const size_t MAX_LINE   = 100000;
    const size_t CLEAN_TIME = 7 * 24 * 3600;

    class spin_mutex {
    public:
        spin_mutex() = default;
        spin_mutex(const spin_mutex&) = delete;
        spin_mutex& operator = (const spin_mutex&) = delete;
        void lock() {
            while(flag.test_and_set(std::memory_order_acquire));
        }
        void unlock() {
            flag.clear(std::memory_order_release);
        }
    private:
        std::atomic_flag flag = ATOMIC_FLAG_INIT;
    }; //spin_mutex

    template <typename T>
    struct level_names {};
    template <> struct level_names<log_level> {
        constexpr std::array<const char*, 7> operator()() const {
            return { "UNKNW", "DEBUG", "INFO", "WARN", "ERROR","FATAL", "DUMP" };
        }
    };

    template <typename T>
    struct level_colors {};
    template <> struct level_colors<log_level> {
        constexpr std::array<const char*, 7> operator()() const {
            return { "\x1b[32m", "\x1b[37m", "\x1b[32m", "\x1b[33m", "\x1b[31m", "\x1b[31m", "\x1b[32m" };
        }
    };

    class log_filter {
    public:
        void filter(log_level llv, bool on);
        bool is_filter(log_level llv) const;

    private:
        unsigned switch_bits_ = -1;
    }; // class log_filter

    class log_time : public ::tm {
    public:
        static log_time now();
        log_time(const ::tm& tm, int usec) : ::tm(tm), tm_usec(usec) { }
        log_time() { }

    public:
        int tm_usec = 0;
    }; // class log_time

    class log_message {
    public:
        int line() const { return line_; }
        bool is_grow() const { return grow_; }
        void set_grow(bool grow) { grow_ = grow; }
        log_level level() const { return level_; }
        const std::string tag() const { return tag_; }
        const std::string msg() const { return msg_; }
        const std::string source() const { return source_; }
        const std::string feature() const { return feature_; }
        const log_time& get_log_time()const { return log_time_; }
        void option(log_level level, std::string& msg, std::string& tag, std::string& feature, std::string& source, int line);

    private:
        int                 line_ = 0;
        bool                grow_ = false;
        log_time            log_time_;
        std::string         source_, msg_, feature_, tag_;
        log_level           level_ = log_level::LOG_LEVEL_DEBUG;
    }; // class log_message
    typedef std::list<std::shared_ptr<log_message>> log_message_list;

    class log_message_pool {
    public:
        log_message_pool(size_t msg_size);
        ~log_message_pool();

        std::shared_ptr<log_message> allocate();
        void release(std::shared_ptr<log_message> logmsg);

    private:
        spin_mutex mutex_;
        std::shared_ptr<log_message_list> free_messages_ = std::make_shared<log_message_list>();
        std::shared_ptr<log_message_list> alloc_messages_ = std::make_shared<log_message_list>();
    }; // class log_message_pool

    class log_message_queue {
    public:
        void put(std::shared_ptr<log_message> logmsg);
        std::shared_ptr<log_message_list> timed_getv();

    private:
        spin_mutex                  spin_;
        std::mutex                  mutex_;
        std::condition_variable     condv_;
        std::shared_ptr<log_message_list> read_messages_ = std::make_shared<log_message_list>();
        std::shared_ptr<log_message_list> write_messages_ = std::make_shared<log_message_list>();
    }; // class log_message_queue

    class log_dest {
    public:
        virtual void flush() {};
        virtual void write(std::shared_ptr<log_message> logmsg);
        virtual void raw_write(std::string& msg, log_level lvl) = 0;
        virtual void ignore_prefix(bool prefix) { ignore_prefix_ = prefix; }
        virtual void ignore_suffix(bool suffix) { ignore_suffix_ = suffix; }
        virtual std::string build_prefix(std::shared_ptr<log_message> logmsg);
        virtual std::string build_suffix(std::shared_ptr<log_message> logmsg);

    protected:
        bool ignore_suffix_ = true;
        bool ignore_prefix_ = false;
    }; // class log_dest

    class stdio_dest : public log_dest {
    public:
        virtual void raw_write(std::string& msg, log_level lvl);
    }; // class stdio_dest

    class log_file_base : public log_dest {
    public:
        log_file_base(size_t max_line) : line_(0), max_line_(max_line) {}
        virtual ~log_file_base();

        const log_time& file_time() const;
        virtual void raw_write(std::string& msg, log_level lvl);
        virtual void flush();

    protected:
        void create(path file_path, std::string& file_name, const log_time& file_time);

        log_time        file_time_;
        size_t          line_, max_line_;
        std::unique_ptr<std::ofstream> file_ = nullptr;
    }; // class log_file

    class rolling_hourly {
    public:
        bool eval(const log_file_base* log_file, const std::shared_ptr<log_message> logmsg) const;
    }; // class rolling_hourly

    class rolling_daily {
    public:
        bool eval(const log_file_base* log_file, const std::shared_ptr<log_message> logmsg) const;
    }; // class rolling_daily

    template<class rolling_evaler>
    class log_rollingfile : public log_file_base {
    public:
        log_rollingfile(path& log_path, std::string& namefix, size_t max_line = 10000, size_t clean_time = CLEAN_TIME);

        virtual void write(std::shared_ptr<log_message> logmsg);

    protected:
        std::string new_log_file_path(const std::shared_ptr<log_message> logmsg);

        path                    log_path_;
        std::string             feature_;
        rolling_evaler          rolling_evaler_;
        size_t                  clean_time_ = CLEAN_TIME;
    }; // class log_rollingfile

    typedef log_rollingfile<rolling_hourly> log_hourlyrollingfile;
    typedef log_rollingfile<rolling_daily> log_dailyrollingfile;

    class logger {
    public:
        virtual void stop() = 0;
        virtual void start() = 0;
        virtual void daemon(bool status) = 0;
        virtual bool is_filter(log_level lv) = 0;
        virtual void filter(log_level lv, bool on) = 0;
        virtual void set_max_line(size_t max_line) = 0;
        virtual void set_clean_time(size_t clean_time) = 0;
        virtual void del_dest(std::string& feature) = 0;
        virtual void del_lvl_dest(log_level log_lvl) = 0;
        virtual bool add_lvl_dest(log_level log_lvl) = 0;
        virtual void ignore_prefix(std::string& feature, bool prefix) = 0;
        virtual void ignore_suffix(std::string& feature, bool suffix) = 0;
        virtual bool add_dest(std::string& feature, std::string& log_path) = 0;
        virtual void option(std::string& log_path, std::string& service, std::string& index, rolling_type type) = 0;
        virtual void output(log_level level, std::string& msg, std::string tag, std::string feature, std::string source = "", int line = 0) = 0;
    };

    class log_service : public logger {
    public:
        void stop();
        void start();

        void daemon(bool status) { log_daemon_ = status; }
        void option(std::string& log_path, std::string& service, std::string& index, rolling_type type);

        bool add_dest(std::string& feature, std::string& log_path);
        bool add_lvl_dest(log_level log_lvl);

        void del_dest(std::string& feature);
        void del_lvl_dest(log_level log_lvl);

        void ignore_prefix(std::string& feature, bool prefix);
        void ignore_suffix(std::string& feature, bool suffix);

        void set_max_line(size_t max_line) { max_line_ = max_line; }
        void set_clean_time(size_t clean_time) { clean_time_ = clean_time; }

        bool is_filter(log_level lv) { return log_filter_.is_filter(lv); }
        void filter(log_level lv, bool on) { log_filter_.filter(lv, on); }

        void output(log_level level, std::string& msg, std::string tag, std::string feature, std::string source, int line);

    protected:
        path build_path(std::string feature, std::string fpath);
        void flush();
        void run();

        path            log_path_;
        spin_mutex      mutex_;
        log_filter      log_filter_;
        rolling_type    rolling_type_;
        std::thread     thread_;
        std::string     service_;
        std::shared_ptr<log_dest> std_dest_ = nullptr;
        std::shared_ptr<log_dest> def_dest_ = nullptr;
        std::shared_ptr<log_message> stop_msg_ = nullptr;
        std::shared_ptr<log_message_queue> logmsgque_ = nullptr;
        std::shared_ptr<log_message_pool> message_pool_ = nullptr;
        std::unordered_map<log_level, std::shared_ptr<log_dest>> dest_lvls_;
        std::unordered_map<std::string, std::shared_ptr<log_dest>> dest_features_;
        size_t max_line_ = MAX_LINE, clean_time_ = CLEAN_TIME;
        bool log_daemon_ = false, ignore_postfix_ = true;
    }; // class log_service

    extern "C" LUALIB_API logger* get_logger();
}

#define LOG_WARN(msg) logger::get_logger()->output(logger::log_level::LOG_LEVEL_WARN, msg, "", "", __FILE__, __LINE__)
#define LOG_INFO(msg) logger::get_logger()->output(logger::log_level::LOG_LEVEL_INFO, msg, "", "", __FILE__, __LINE__)
#define LOG_DUMP(msg) logger::get_logger()->output(logger::log_level::LOG_LEVEL_DUMP, msg, "", "", __FILE__, __LINE__)
#define LOG_DEBUG(msg) logger::get_logger()->output(logger::log_level::LOG_LEVEL_DEBUG, msg, "", "", __FILE__, __LINE__)
#define LOG_ERROR(msg) logger::get_logger()->output(logger::log_level::LOG_LEVEL_ERROR, msg, "", "", __FILE__, __LINE__)
#define LOG_FATAL(msg) logger::get_logger()->output(logger::log_level::LOG_LEVEL_FATAL, msg, "", "", __FILE__, __LINE__)
#define LOGF_WARN(msg, feature) get_logger()->output(logger::log_level::LOG_LEVEL_WARN, msg, "", feature, __FILE__, __LINE__)
#define LOGF_INFO(msg, feature) get_logger()->output(logger::log_level::LOG_LEVEL_INFO, msg, "", feature, __FILE__, __LINE__)
#define LOGF_DUMP(msg, feature) get_logger()->output(logger::log_level::LOG_LEVEL_DUMP, msg, "", feature, __FILE__, __LINE__)
#define LOGF_DEBUG(msg, feature) get_logger()->output(logger::log_level::LOG_LEVEL_DEBUG, msg, "", feature, __FILE__, __LINE__)
#define LOGF_ERROR(msg, feature) get_logger()->output(logger::log_level::LOG_LEVEL_ERROR, msg, "", feature, __FILE__, __LINE__)
#define LOGF_FATAL(msg, feature) get_logger()->output(logger::log_level::LOG_LEVEL_FATAL, msg, "", feature, __FILE__, __LINE__)
#define LOGTF_WARN(msg, tag, feature) get_logger()->output(logger::log_level::LOG_LEVEL_WARN, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_INFO(msg, tag, feature) get_logger()->output(logger::log_level::LOG_LEVEL_INFO, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_DUMP(msg, tag, feature) get_logger()->output(logger::log_level::LOG_LEVEL_DUMP, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_DEBUG(msg, tag, feature) get_logger()->output(logger::log_level::LOG_LEVEL_DEBUG, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_ERROR(msg, tag, feature) get_logger()->output(logger::log_level::LOG_LEVEL_ERROR, msg, tag, feature, __FILE__, __LINE__)
#define LOGTF_FATAL(msg, tag, feature) get_logger()->output(logger::log_level::LOG_LEVEL_FATAL, msg, tag, feature, __FILE__, __LINE__)
