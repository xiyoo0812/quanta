#define LUA_LIB
#include "logger.h"

#ifdef WIN32
#include <windows.h>
#endif

namespace logger {
    // class log_message
    // --------------------------------------------------------------------------------
    void log_message::option(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int32_t line) {
        time_ = time_point_cast<milliseconds>(system_clock::now());
        suffix_ = std::format("[{}:{}]", source, line);
        feature_ = feature;
        level_ = level;
        tag_ = tag;
        msg_ = msg;
    }

    zone_time log_message::prepare(time_zone* zone) {
        auto time = zoned_time(zone, time_);
        prefix_ = std::format("[{:%Y-%m-%d %H:%M:%S}][{}][{}] ", time, tag_, level_names[(int)level_]);
        return time;
    }

    sstring log_message::format(bool prefix, bool suffix, bool clr) {
        return std::format("{}{}{}{}\x1b[0m\n", clr ? level_colors[(int)level_] : "", prefix ? prefix_ : "", msg_, suffix ? suffix_ : "");
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
    void log_dest::write(sptr<log_message> msg, const zone_time& logtime) {
        line_++;
        auto logtxt = msg->format(prefix_, suffix_, color());
        size_t msize = logtxt.size();
        if (size_ + msize >= USHRT_MAX) flush(logtime);
        if (output_) output_(logtxt.c_str(), logtxt.size(), (int)msg->level());
        else raw_write(logtxt, msize);
    }

    // class stdio_dest
    // --------------------------------------------------------------------------------
    bool stdio_dest::color() {
#ifdef WIN32
        return true;
#endif // WIN32
        return false;
    }

    void stdio_dest::flush(const zone_time& time) {
        if (size_ == 0) return;
        std::cout.write(log_buf_, size_);
        size_ = 0;
    }

    void stdio_dest::raw_write(vstring logtxt, size_t size) {
        if (size >= USHRT_MAX) {
            std::cout.write(logtxt.data(), size);
            return;
        }
        memcpy(log_buf_ + size_, logtxt.data(), size);
        size_ += size;
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

    void log_file_base::flush(const zone_time& time) {
        if (size_ == 0) return;
        file_->write(log_buf_, size_);
        file_->flush();
        size_ = 0;
    }

    void log_file_base::raw_write(vstring logtxt, size_t size) {
        if (size >= USHRT_MAX) {
            file_->write(log_buf_, size);
            return;
        }
        memcpy(log_buf_ + size_, logtxt.data(), size);
        size_ += size;
    }

    void log_file_base::create(fspath file_path, sstring file_name, const zone_time& time) {
        if (file_) {
            file_->flush();
            file_->close();
        }
        file_path.append(file_name);
        file_time_ = time.get_local_time();
        file_ = std::make_unique<std::ofstream>(file_path, std::ios::binary | std::ios::out | std::ios::app);
    }

    // class rolling_hourly
    // --------------------------------------------------------------------------------
    bool rolling_hourly::eval(const local_time<microseconds>& filetime, const zone_time& logtime) const {
        return floor<hours>(logtime.get_local_time()) != floor<hours>(filetime);
    }

    // class rolling_daily
    // --------------------------------------------------------------------------------
    bool rolling_daily::eval(const local_time<microseconds>& filetime, const zone_time& logtime) const {
        return floor<days>(logtime.get_local_time()) != floor<days>(filetime);
    }

    // class log_rollingfile
    // --------------------------------------------------------------------------------
    template<class rolling_evaler>
    log_rollingfile<rolling_evaler>::log_rollingfile(fspath& log_path, const zone_time& time, vstring feature, size_t max_line)
        : log_file_base(max_line, time), log_path_(log_path), feature_(feature){
    }

    template<class rolling_evaler>
    void log_rollingfile<rolling_evaler>::flush(const zone_time& time) {
        if (file_ == nullptr || rolling_evaler_.eval(file_time_, time) || line_ > max_line_) {
            try {
                create_directories(log_path_);
                create(log_path_, new_log_file_name(time), time);
            } catch (...) {}
            assert(file_);
        }
        log_file_base::flush(time);
    }

    template<class rolling_evaler>
    sstring log_rollingfile<rolling_evaler>::new_log_file_name(const zone_time& time) {
        return std::format("{}-{:%Y%m%d-%H%M%S}.p{}.log", feature_, time, ::getpid());
    }

    // class log_service
    // --------------------------------------------------------------------------------
    bool log_service::option(fspath log_path, cpchar service, cpchar index) {
        if (main_dest_) return true;
        log_path_ = log_path;
        zone_ = const_cast<time_zone*>(current_zone());
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
            auto ztime = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
            if (rolling_type_ == DAYLY) {
                logfile = std::make_shared<log_dailyrollingfile>(logger_path, ztime, feature, max_line_);
            } else {
                logfile = std::make_shared<log_hourlyrollingfile>(logger_path, ztime, feature, max_line_);
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
            auto ztime = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
            std::lock_guard<spin_mutex> lock(mutex_);
            if (rolling_type_ == DAYLY) {
                auto logfile = std::make_shared<log_dailyrollingfile>(logger_path, ztime, feature, max_line_);
                dest_lvls_.insert(std::make_pair(log_lvl, logfile));
            } else {
                auto logfile = std::make_shared<log_hourlyrollingfile>(logger_path, ztime, feature, max_line_);
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
                auto ztime = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
                auto logfile = std::make_shared<log_file_base>(max_line_, ztime);
                logfile->create(logger_path, fname, ztime);
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
        auto time = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
        std::lock_guard<spin_mutex> lock(mutex_);
        if (main_dest_) main_dest_->flush(time);
        if (std_dest_) std_dest_->flush(time);
        for (auto dest : dest_features_)
            dest.second->flush(time);
        for (auto dest : dest_lvls_)
            dest.second->flush(time);
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
                    auto ztime = logmsg->prepare(zone_);
                    if (log_std_) std_dest_->write(logmsg, ztime);
                    if (auto it = dest_features_.find(logmsg->feature()); it != dest_features_.end()) {
                        it->second->write(logmsg, ztime);
                        continue;
                    }
                    if (auto it = dest_lvls_.find(logmsg->level()); it != dest_lvls_.end()) {
                        it->second->write(logmsg, ztime);
                    }
                    main_dest_->write(logmsg, ztime);
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
        if (on)
            filter_bits_ |= (1 << ((int)llv - 1));
        else
            filter_bits_ &= ~(1 << ((int)llv - 1));
    }
}
