#define LUA_LIB
#include "logger.h"

namespace logger {
    inline void format_time(pchar secbuf, cpchar fmt, const log_time& time) {
        std::tm loc_tm;
        auto time_t = system_clock::to_time_t(time);
#ifdef _WIN32
        localtime_s(&loc_tm, &time_t);
#else
        localtime_r(&time_t, &loc_tm);
#endif
        std::strftime(secbuf, 32, fmt, &loc_tm);
    }

    // class log_message
    // --------------------------------------------------------------------------------
    void log_message::option(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int32_t line) {
        time_ = system_clock::now();
        suffix_ = std::format("[{}:{}]", source, line);
        feature_ = feature;
        level_ = level;
        tag_ = tag;
        msg_ = msg;
    }

    void log_message::prepare(pchar secbuf, seconds& last) {
        auto point = time_.time_since_epoch();
        if (auto now = duration_cast<seconds>(point); now != last) {
            last = now;
            format_time(secbuf, "%Y-%m-%d %H:%M:%S", time_);
        }
        auto ms = duration_cast<milliseconds>(point) % 1000;
        prefix_ = std::format("[{}.{:03}][{}][{}] ", secbuf, ms.count(), tag_, level_names[(int)level_]);
    }

    sstring log_message::format(bool prefix, bool suffix, bool crcn) {
        return std::format("{}{}{}{}", prefix ? prefix_ : "", msg_, suffix ? suffix_ : "", crcn ? "\n" : "");
    }

    // class log_message_pool
    // --------------------------------------------------------------------------------
    sptr<log_message> log_message_pool::allocate() {
        if (alloc_msgs_->empty()) {
            if (free_msgs_->empty()) {
                free_msgs_->reserve(QUEUE_SIZE);
                alloc_msgs_->reserve(QUEUE_SIZE);
                for (size_t i = 0; i < QUEUE_SIZE; ++i) {
                    alloc_msgs_->push_back(std::make_shared<log_message>());
                }
            } else {
                std::lock_guard<spin_mutex> lock(mutex_);
                alloc_msgs_.swap(free_msgs_);
            }
        }
        if (alloc_msgs_->empty()) {
            return std::make_shared<log_message>();
        }
        auto logmsg = alloc_msgs_->back();
        alloc_msgs_->pop_back();
        return logmsg;
    }

    void log_message_pool::recycle(sptr<log_messages> logmsgs) {
        std::lock_guard<spin_mutex> lock(mutex_);
        size_t fspace = free_msgs_->capacity() - free_msgs_->size();
        size_t n = std::min(fspace, logmsgs->size());
        if (n == 0) return;
        auto siter = logmsgs->begin();
        free_msgs_->insert(free_msgs_->end(), std::make_move_iterator(siter), std::make_move_iterator(siter + n));
    }

    // class log_message_queue
    // --------------------------------------------------------------------------------
    void log_message_queue::put(sptr<log_message> logmsg) {
        std::lock_guard<spin_mutex> lock(mutex_);
        write_msgs_->push_back(std::move(logmsg));
    }

    sptr<log_messages> log_message_queue::timed_getv(bool running) {
        if (running) {
            if (write_msgs_->empty()) return nullptr;
            std::unique_lock<spin_mutex> lock(mutex_, std::try_to_lock);
            if (lock.owns_lock()) {
                read_msgs_.swap(write_msgs_);
                return read_msgs_;
            }
            return nullptr;
        }
        std::lock_guard<spin_mutex> lock(mutex_);
        read_msgs_.swap(write_msgs_);
        return read_msgs_;
    }

    // class log_dest
    // --------------------------------------------------------------------------------
    void log_dest::write(sptr<log_message> msg) {
        line_++;
        auto logtxt = msg->format(prefix_, suffix_, crcn());
        if (output_) output_(logtxt.c_str(), logtxt.size(), (int)msg->level());
        else raw_write(logtxt, msg->level());
    }

    // class stdio_dest
    // --------------------------------------------------------------------------------
    void stdio_dest::raw_write(vstring logtxt, log_level lvl) {
#ifdef WIN32
        std::cout << level_colors[(int)lvl] << logtxt << "\x1b[0m" << std::endl;
#else
        std::cout << logtxt << std::endl;
#endif
    }

    // class log_file_base
    // --------------------------------------------------------------------------------
    log_file_base::~log_file_base() {
        if (file_) {
            file_->write(log_buf_, size_);
            file_->flush();
            file_->close();
        }
    }

    void log_file_base::flush() {
        if (size_ == 0) return;
        file_->write(log_buf_, size_);
        file_->flush();
        size_ = 0;
    }

    void log_file_base::raw_write(vstring logtxt, log_level lvl) {
        size_t size = logtxt.size();
        if (size_ + size >= USHRT_MAX) flush();
        if (size >= USHRT_MAX) {
            file_->write(log_buf_, size);
            return;
        }
        memcpy(log_buf_ + size_, logtxt.data(), size);
        size_ += size;
    }

    void log_file_base::create(fspath file_path, sstring file_name) {
        if (file_) {
            file_->flush();
            file_->close();
        }
        file_path.append(file_name);
        file_time_ = system_clock::now();
        file_ = std::make_unique<std::ofstream>(file_path, std::ios::binary | std::ios::out | std::ios::app);
    }

    // class rolling_hourly
    // --------------------------------------------------------------------------------
    bool rolling_hourly::eval(const log_time& filetime, const log_time& logtime) const {
        return floor<hours>(logtime) != floor<hours>(filetime);
    }

    // class rolling_daily
    // --------------------------------------------------------------------------------
    bool rolling_daily::eval(const log_time& filetime, const log_time& logtime) const {
        return floor<days>(logtime) != floor<days>(filetime);
    }

    // class log_rollingfile
    // --------------------------------------------------------------------------------
    template<class rolling_evaler>
    log_rollingfile<rolling_evaler>::log_rollingfile(fspath& log_path, vstring feature, size_t max_line) 
        : log_file_base(max_line), log_path_(log_path), feature_(feature) {
    }

    template<class rolling_evaler>
    void log_rollingfile<rolling_evaler>::flush() {
        auto time = system_clock::now();
        if (file_ == nullptr || rolling_evaler_.eval(file_time_, time) || line_ > max_line_) {
            try {
                create_directories(log_path_);
                create(log_path_, new_log_file_name(time));
            } catch (...) {}
            assert(file_);
        }
        log_file_base::flush();
    }

    template<class rolling_evaler>
    sstring log_rollingfile<rolling_evaler>::new_log_file_name(const log_time& time) {
        char buffer[32];
        format_time(buffer,"%Y%m%d-%H%M%S", time);
        auto ms = duration_cast<milliseconds>(time.time_since_epoch()) % 1000;
        return std::format("{}-{}.{:03}.p{}.log", feature_, buffer, ms.count(), ::getpid());
    }

    // class log_service
    // --------------------------------------------------------------------------------
    bool log_service::option(fspath log_path, cpchar service, cpchar index) {
        if (main_dest_) return true;
        log_path_ = log_path;
        service_ = std::format("{}-{}", service, index);
        try {
            create_directories(log_path_);
            add_dest(service);
            //启动日志线程
            thread_ = std::jthread(std::bind(&log_service::run, this, std::placeholders::_1));
            return true;
        } catch (...) {}
        return false;
    }

    fspath log_service::build_path(cpchar feature) {
        fspath log_path = log_path_;
        if (strncmp(service_.c_str(), feature, strlen(feature)) == 0) {
            log_path.append(service_);
        } else {
            log_path.append(feature);
        }
        return log_path;
    }

    bool log_service::add_dest(cpchar feature) {
        std::lock_guard<spin_mutex> lock(mutex_);
        if (!dest_features_.contains(feature)) {
            sptr<log_dest> logfile = nullptr;
            fspath logger_path = build_path(feature);
            if (rolling_type_ == DAILY) {
                logfile = std::make_shared<log_dailyrollingfile>(logger_path, feature, max_line_);
            } else {
                logfile = std::make_shared<log_hourlyrollingfile>(logger_path, feature, max_line_);
            }
            if (!main_dest_) {
                main_dest_ = logfile;
                return true;
            }
            dest_features_.insert(std::make_pair(feature, logfile));
        }
        return true;
    }

    bool log_service::add_lvl_dest(log_level log_lvl) {
        if (!dest_lvls_.contains(log_lvl)) {
            sstring feature = level_names[(int)log_lvl];
            std::transform(feature.begin(), feature.end(), feature.begin(), [](auto c) { return std::tolower(c); });
            fspath logger_path = build_path(service_.c_str());
            logger_path.append(feature);
            std::lock_guard<spin_mutex> lock(mutex_);
            if (rolling_type_ == DAILY) {
                auto logfile = std::make_shared<log_dailyrollingfile>(logger_path, feature, max_line_);
                dest_lvls_.insert(std::make_pair(log_lvl, logfile));
            } else {
                auto logfile = std::make_shared<log_hourlyrollingfile>(logger_path, feature, max_line_);
                dest_lvls_.insert(std::make_pair(log_lvl, logfile));
            }
        }
        return true;
    }

    bool log_service::add_file_dest(cpchar feature, cpchar fname) {
        std::lock_guard<spin_mutex> lock(mutex_);
        if (!dest_features_.contains(feature)) {
            try {
                fspath logger_path = build_path(service_.c_str());
                create_directories(logger_path);
                auto logfile = std::make_shared<log_file_base>(max_line_);
                logfile->create(logger_path, fname);
                logfile->ignore_prefix(true);
                dest_features_.insert(std::make_pair(feature, logfile));
            } catch (...) {}
        }
        return true;
    }

    void log_service::del_agent(log_agent* agent) {
        std::lock_guard<spin_mutex> lock(mutex_);
        agents_.erase(agent);
    }

    void log_service::add_agent(log_agent* agent) {
        std::lock_guard<spin_mutex> lock(mutex_);
        agents_.emplace(agent);
    }

    void log_service::del_dest(cpchar feature) {
        std::lock_guard<spin_mutex> lock(mutex_);
        dest_features_.erase(feature);
    }

    void log_service::del_lvl_dest(log_level log_lvl) {
        std::lock_guard<spin_mutex> lock(mutex_);
        dest_lvls_.erase(log_lvl);
    }

    void log_service::ignore_prefix(cpchar feature, bool prefix) {
        if (auto it = dest_features_.find(feature); it != dest_features_.end()) {
            it->second->ignore_prefix(prefix);
        }
    }

    void log_service::ignore_suffix(cpchar feature, bool suffix) {
        if (auto it = dest_features_.find(feature); it != dest_features_.end()) {
            it->second->ignore_suffix(suffix);
        }
    }

    log_service::log_service(){
        std_dest_ = std::make_shared<stdio_dest>();
    }

    log_service::~log_service() {
        thread_.request_stop();
        if (thread_.joinable()) {
            thread_.join();
        }
        agents_.clear();
        dest_lvls_.clear();
        dest_features_.clear();
        main_dest_ = nullptr;
        std_dest_ = nullptr;
    }

    void log_service::flush() {
        std::lock_guard<spin_mutex> lock(mutex_);
        if (main_dest_) main_dest_->flush();
        if (std_dest_) std_dest_->flush();
        for (auto dest : dest_features_)
            dest.second->flush();
        for (auto dest : dest_lvls_)
            dest.second->flush();
    }

    void log_service::run(std::stop_token stoken) {
        std::this_thread::sleep_for(milliseconds(100));
        while (true) {
            if (stoken.stop_requested()) {
                running_ = false;
            }
            bool empty = true;
            for (auto& agent : agents_) {
                auto logmsgs = agent->timed_getv(running_);
                if (logmsgs == nullptr) continue;
                for (auto logmsg : *logmsgs) {
                    logmsg->prepare(time_buf_, last_time_);
                    if (log_std_) std_dest_->write(logmsg);
                    if (auto it = dest_features_.find(logmsg->feature()); it != dest_features_.end()) {
                        it->second->write(logmsg);
                        continue;
                    }
                    if (auto it = dest_lvls_.find(logmsg->level()); it != dest_lvls_.end()) {
                        it->second->write(logmsg);
                    }
                    main_dest_->write(logmsg);
                }
                empty = false;
                agent->recycle(logmsgs);
                logmsgs->clear();
            }
            if (empty) {
                if (!running_) break;
                std::this_thread::sleep_for(milliseconds(50));
            } else {
                flush();
            }
        }
    }

    log_agent::log_agent() {
        logmsgque_ = std::make_shared<log_message_queue>();
        message_pool_ = std::make_shared<log_message_pool>();
    }

    log_agent::~log_agent() {
        if (auto service = service_.lock(); service) {
            service->del_agent(this);
        }
    }

    void log_agent::attach(wptr<log_service> service) {
        service_ = service;
        if (auto lservice = service_.lock(); lservice) {
            lservice->add_agent(this);
        }
    }

    void log_agent::output(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int line) {
        if (!is_filter(level)) {
            auto logmsg_ = message_pool_->allocate();
            logmsg_->option(level, std::move(msg), tag, feature, source, line);
            logmsgque_->put(logmsg_);
        }
    }

    void log_agent::filter(log_level llv, bool on) {
        if (on) filter_bits_ |= (1 << ((int)llv - 1));
        else filter_bits_ &= ~(1 << ((int)llv - 1));
    }
}
