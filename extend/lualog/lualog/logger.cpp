#define LUA_LIB
#include "logger.h"

namespace logger {

    // class log_filter
    // --------------------------------------------------------------------------------
    void log_filter::filter(log_level llv, bool on) {
        if (on)
            switch_bits_ |= (1 << ((int)llv - 1));
        else
            switch_bits_ &= ~(1 << ((int)llv - 1));
    }
    bool log_filter::is_filter(log_level llv) const {
        return 0 == (switch_bits_ & (1 << ((int)llv - 1)));
    }

    // class log_time
    // --------------------------------------------------------------------------------
    log_time log_time::now() {
        system_clock::duration dur = system_clock::now().time_since_epoch();
        time_t time = duration_cast<seconds>(dur).count();
        auto time_ms = duration_cast<milliseconds>(dur).count();
        return log_time(*std::localtime(&time), time_ms % 1000);
    }

    // class log_message
    // --------------------------------------------------------------------------------
    void log_message::option(log_level level, const cstring& msg, cstring& tag, cstring& feature, cstring& source, int line) {
        log_time_ = log_time::now();
        feature_ = feature;
        source_ = source;
        level_ = level;
        line_ = line;
        msg_ = msg;
        tag_ = tag;
    }

    // class log_message_pool
    // --------------------------------------------------------------------------------
    log_message_pool::log_message_pool(size_t msg_size) {
        for (size_t i = 0; i < msg_size; ++i) {
            alloc_messages_->push_back(std::make_shared<log_message>());
        }
    }
    log_message_pool::~log_message_pool() {
        alloc_messages_->clear();
        free_messages_->clear();
    }
    sptr<log_message> log_message_pool::allocate() {
        if (alloc_messages_->empty()) {
            std::unique_lock<spin_mutex> lock(mutex_);
            alloc_messages_.swap(free_messages_);
        }
        if (alloc_messages_->empty()) {
            auto logmsg = std::make_shared<log_message>();
            logmsg->set_grow(true);
            return logmsg;
        }
        std::unique_lock<spin_mutex> lock(mutex_);
        auto logmsg = alloc_messages_->front();
        alloc_messages_->pop_front();
        return logmsg;
    }
    void log_message_pool::release(sptr<log_message> logmsg) {
        if (!logmsg->is_grow()) {
            std::unique_lock<spin_mutex> lock(mutex_);
            free_messages_->push_back(logmsg);
        }
    }

    // class log_message_queue
    // --------------------------------------------------------------------------------
    void log_message_queue::put(sptr<log_message> logmsg) {
        std::unique_lock<spin_mutex> lock(spin_);
        write_messages_->push_back(logmsg);
    }

    sptr<log_message_list> log_message_queue::timed_getv() {
        {
            read_messages_->clear();
            std::unique_lock<spin_mutex> lock(spin_);
            read_messages_.swap(write_messages_);
        }
        if (read_messages_->empty()) {
            std::unique_lock<std::mutex> lock(mutex_);
            condv_.wait_for(lock, milliseconds(5));
        }
        return read_messages_;
    }

    // class log_dest
    // --------------------------------------------------------------------------------
    inline void log_dest::write(sptr<log_message> logmsg) {
        auto logtxt = fmt::format("{} {}{}\n", build_prefix(logmsg), logmsg->msg(), build_suffix(logmsg));
        raw_write(logtxt, logmsg->level());
    }

    inline cstring log_dest::build_prefix(sptr<log_message> logmsg) {
        if (!ignore_prefix_) {
            auto names = level_names<log_level>()();
            const log_time& t = logmsg->get_log_time();
            return fmt::format("[{:4d}-{:02d}-{:02d} {:02d}:{:02d}:{:02d}.{:03d}]{}[{}]",
                t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec, t.tm_usec, logmsg->tag(), names[(int)logmsg->level()]);
        }
        return "";
    }

    inline cstring log_dest::build_suffix(sptr<log_message> logmsg) {
        if (!ignore_suffix_) {
            return fmt::format("[{}:{}]", logmsg->source().c_str(), logmsg->line());
        }
        return "";
    }

    // class stdio_dest
    // --------------------------------------------------------------------------------
    void stdio_dest::raw_write(cstring& msg, log_level lvl) {
#ifdef WIN32
        auto colors = level_colors<log_level>()();
        std::cout << colors[(int)lvl];
#endif // WIN32
        std::cout << msg;
    }

    // class log_file_base
    // --------------------------------------------------------------------------------
    log_file_base::~log_file_base() {
        if (file_) {
            file_->flush();
            file_->close();
        }
    }
    void log_file_base::raw_write(cstring& msg, log_level lvl) {
        if (file_) file_->write(msg.c_str(), msg.size());
    }
    void log_file_base::flush() {
        if (file_) file_->flush();
    }
    const log_time& log_file_base::file_time() const { return file_time_; }

    void log_file_base::create(path file_path, cstring& file_name, const log_time& file_time) {
        if (file_) {
            file_->flush();
            file_->close();
        }
        file_time_ = file_time;
        file_path.append(file_name);
        file_ = std::make_unique<std::ofstream>(file_path, std::ios::binary | std::ios::out | std::ios::app);
    }

    // class rolling_hourly
    // --------------------------------------------------------------------------------
    bool rolling_hourly::eval(const log_file_base* log_file, const sptr<log_message> logmsg) const {
        const log_time& ftime = log_file->file_time();
        const log_time& ltime = logmsg->get_log_time();
        return ltime.tm_year != ftime.tm_year || ltime.tm_mon != ftime.tm_mon ||
            ltime.tm_mday != ftime.tm_mday || ltime.tm_hour != ftime.tm_hour;
    }

    // class rolling_daily
    // --------------------------------------------------------------------------------
    bool rolling_daily::eval(const log_file_base* log_file, const sptr<log_message> logmsg) const {
        const log_time& ftime = log_file->file_time();
        const log_time& ltime = logmsg->get_log_time();
        return ltime.tm_year != ftime.tm_year || ltime.tm_mon != ftime.tm_mon || ltime.tm_mday != ftime.tm_mday;
    }

    // class log_rollingfile
    // --------------------------------------------------------------------------------
    template<class rolling_evaler>
    log_rollingfile<rolling_evaler>::log_rollingfile(path& log_path, cstring& feature, size_t max_line, size_t clean_time)
        : log_file_base(max_line), log_path_(log_path), feature_(feature), clean_time_(clean_time){
    }

    template<class rolling_evaler>
    void log_rollingfile<rolling_evaler>::write(sptr<log_message> logmsg) {
            line_++;
            if (file_ == nullptr || rolling_evaler_.eval(this, logmsg) || line_ >= max_line_) {
                create_directories(log_path_);
                try {
                    for (auto entry : recursive_directory_iterator(log_path_)) {
                        if (!entry.is_directory() && entry.path().extension().string() == ".log") {
                            auto ftime = last_write_time(entry.path());
                            if ((size_t)duration_cast<seconds>(file_time_type::clock::now() - ftime).count() > clean_time_) {
                                remove(entry.path());
                            }
                        }
                    }
                } catch (...) {}
                create(log_path_, new_log_file_path(logmsg), logmsg->get_log_time());
                assert(file_);
                line_ = 0;
            }
            log_file_base::write(logmsg);
        }

    template<class rolling_evaler>
    cstring log_rollingfile<rolling_evaler>::new_log_file_path(const sptr<log_message> logmsg) {
        const log_time& t = logmsg->get_log_time();
        return fmt::format("{}-{:4d}{:02d}{:02d}-{:02d}{:02d}{:02d}.{:03d}.p{}.log", 
            feature_, t.tm_year + 1900, t.tm_mon + 1, t.tm_mday, t.tm_hour, t.tm_min, t.tm_sec, t.tm_usec, ::getpid());
    }

    // class log_service
    // --------------------------------------------------------------------------------
    void log_service::option(cstring& log_path, cstring& service, cstring& index, rolling_type type) {
        log_path_ = log_path, service_ = service; rolling_type_ = type;
        log_path_.append(fmt::format("{}-{}", service, index));
    }

    path log_service::build_path(cstring& feature, cstring& lpath) {
        if (lpath.empty()) {
            path log_path = log_path_;
            if (feature != service_) {
                log_path.append(feature);
            }
            return log_path;
        }
        return lpath;
    }

    bool log_service::add_dest(cstring& feature, cstring& log_path) {
        std::unique_lock<spin_mutex> lock(mutex_);
        if (dest_features_.find(feature) == dest_features_.end()) {
            sptr<log_dest> logfile = nullptr;
            path logger_path = build_path(feature, log_path);
            if (rolling_type_ == rolling_type::DAYLY) {
                logfile = std::make_shared<log_dailyrollingfile>(logger_path, feature, max_line_, clean_time_);
            } else {
                logfile = std::make_shared<log_hourlyrollingfile>(logger_path, feature, max_line_, clean_time_);
            }
            if (!def_dest_) {
                def_dest_ = logfile;
                return true;
            }
            dest_features_.insert(std::make_pair(feature, logfile));
            return true;
        }
        return true;
    }

    bool log_service::add_lvl_dest(log_level log_lvl) {
        auto names = level_names<log_level>()();
        sstring feature = names[(int)log_lvl];
        std::transform(feature.begin(), feature.end(), feature.begin(), [](auto c) { return std::tolower(c); });
        path logger_path = build_path(feature, "");
        std::unique_lock<spin_mutex> lock(mutex_);
        if (rolling_type_ == rolling_type::DAYLY) {
            auto logfile = std::make_shared<log_dailyrollingfile>(logger_path, feature, max_line_, clean_time_);
            dest_lvls_.insert(std::make_pair(log_lvl, logfile));
        }
        else {
            auto logfile = std::make_shared<log_hourlyrollingfile>(logger_path, feature, max_line_, clean_time_);
            dest_lvls_.insert(std::make_pair(log_lvl, logfile));
        }
        return true;
    }

    void log_service::del_dest(cstring& feature) {
        std::unique_lock<spin_mutex> lock(mutex_);
        auto it = dest_features_.find(feature);
        if (it != dest_features_.end()) {
            dest_features_.erase(it);
        }
    }

    void log_service::del_lvl_dest(log_level log_lvl) {
        std::unique_lock<spin_mutex> lock(mutex_);
        auto it = dest_lvls_.find(log_lvl);
        if (it != dest_lvls_.end()) {
            dest_lvls_.erase(it);
        }
    }

    void log_service::ignore_prefix(cstring& feature, bool prefix) {
        auto iter = dest_features_.find(feature);
        if (iter != dest_features_.end()) {
            iter->second->ignore_prefix(prefix);
            return;
        }
        if (def_dest_) def_dest_->ignore_prefix(prefix);
        if (std_dest_) std_dest_->ignore_prefix(prefix);
        for (auto dest : dest_lvls_) dest.second->ignore_prefix(prefix);
    }

    void log_service::ignore_suffix(cstring& feature, bool suffix) {
        auto iter = dest_features_.find(feature);
        if (iter != dest_features_.end()) {
            iter->second->ignore_suffix(suffix);
            return;
        }
        if (def_dest_) def_dest_->ignore_suffix(suffix);
        if (std_dest_) std_dest_->ignore_suffix(suffix);
        for (auto dest : dest_lvls_) dest.second->ignore_suffix(suffix);
    }

    void log_service::start(){
        if (!stop_msg_ && !std_dest_) {
            logmsgque_ = std::make_shared<log_message_queue>();
            message_pool_ = std::make_shared<log_message_pool>(QUEUE_SIZE);
            std_dest_ = std::make_shared<stdio_dest>();
            stop_msg_ = message_pool_->allocate();
            std::thread(&log_service::run, this).swap(thread_);
        }
    }

    void log_service::stop() {
        if (stop_msg_) {
            logmsgque_->put(stop_msg_);
        }
        if (thread_.joinable()) {
            thread_.join();
        }
    }

    void log_service::flush() {
        std::unique_lock<spin_mutex> lock(mutex_);
        for (auto dest : dest_features_)
            dest.second->flush();
        for (auto dest : dest_lvls_)
            dest.second->flush();
        if (def_dest_) {
            def_dest_->flush();
        }
    }
   
    void log_service::run() {
        bool loop = true;
        while (loop) {
            auto logmsgs = logmsgque_->timed_getv().get();
            for (auto logmsg : *logmsgs) {
                if (logmsg == stop_msg_) {
                    loop = false;
                    continue;
                }
                if (!log_daemon_) {
                    std_dest_->write(logmsg);
                }
                auto it_lvl = dest_lvls_.find(logmsg->level());
                if (it_lvl != dest_lvls_.end()) {
                    it_lvl->second->write(logmsg);
                }
                auto it_fea = dest_features_.find(logmsg->feature());
                if (it_fea != dest_features_.end()) {
                    it_fea->second->write(logmsg);
                } else if (def_dest_) {
                    def_dest_->write(logmsg);
                }
                message_pool_->release(logmsg);
            }
            flush();
        }
    }

    void log_service::output(log_level level, const cstring& msg, cstring& tag, cstring& feature, cstring& source, int line) {
        if (!log_filter_.is_filter(level)) {
            auto logmsg_ = message_pool_->allocate();
            logmsg_->option(level, msg, tag, feature, source, line);
            logmsgque_->put(logmsg_);
        }
    }

    static logger* s_logger = nullptr;
    extern "C" {
        LUALIB_API logger* get_logger() {
            if (s_logger == nullptr) {
                s_logger = new log_service();
                s_logger->start();
            }
            return s_logger;
        }
    }
}
