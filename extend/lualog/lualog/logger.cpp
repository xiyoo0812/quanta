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

    sstring log_message::format(bool prefix, bool suffix) {
        return std::format("{}{}{}\n", prefix ? prefix_ : "", msg_, suffix ? suffix_ : "");
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
        auto logtxt = msg->format(prefix_, suffix_);
        size_t msize = logtxt.size();
        if (size_ + msize >= USHRT_MAX) flush(logtime);
        raw_write(logtxt, msg->color(), msize);
    }

    void log_dest::raw_write(vstring logtxt, vstring color, size_t size) {
        memcpy(log_buf_ + size_, logtxt.data(), size);
        size_ += size;
    }

    // class stdio_dest
    // --------------------------------------------------------------------------------
    void stdio_dest::flush(const zone_time& time) {
        if (size_ == 0) return;
        std::cout.write(log_buf_, size_);
        size_ = 0;
    }

    void stdio_dest::raw_write(vstring logtxt, vstring color, size_t size) {
#ifdef WIN32
        memcpy(log_buf_ + size_, color.data(), color.size());
        size_ += color.size();
#endif // WIN32
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
        size_ = 0;
    }

    void log_file_base::create(path file_path, sstring file_name) {
        if (file_) {
            file_->flush();
            file_->close();
        }
        file_path.append(file_name);
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
    log_rollingfile<rolling_evaler>::log_rollingfile(path& log_path, const zone_time& time, vstring feature, size_t max_line, size_t clean_time)
        : log_file_base(max_line, time), log_path_(log_path), feature_(feature), clean_time_(clean_time){
    }

    template<class rolling_evaler>
    void log_rollingfile<rolling_evaler>::flush(const zone_time& time) {
        if (file_ == nullptr || rolling_evaler_.eval(file_time_, time) || line_ > max_line_) {
            create_directories(log_path_);
            try {
                for (auto entry : recursive_directory_iterator(log_path_)) {
                    if (entry.is_directory() || entry.path().extension().string() != ".log") continue;
                    if (entry.path().stem().has_extension()) {
                        auto ftime = last_write_time(entry.path());
                        if ((size_t)duration_cast<seconds>(file_time_type::clock::now() - ftime).count() > clean_time_) {
                            remove(entry.path());
                        }
                    }
                }
            } catch (...) {}
            create(log_path_, new_log_file_name(time));
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
    void log_service::option(cpchar log_path, cpchar service, cpchar index, cpchar zone) {
        if (main_dest_) return;
        log_path_ = log_path;
        service_ = std::format("{}-{}", service, index);
        zone_ = const_cast<time_zone*>(locate_zone(zone));
        create_directories(log_path);
        add_dest(service);
        //启动日志线程
        thread_ = std::jthread(std::bind(&log_service::run, this, std::placeholders::_1));
    }

    path log_service::build_path(cpchar feature) {
        path log_path = log_path_;
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
            path logger_path = build_path(feature);
            auto ztime = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
            if (rolling_type_ == DAYLY) {
                logfile = std::make_shared<log_dailyrollingfile>(logger_path, ztime, feature, max_line_, clean_time_);
            } else {
                logfile = std::make_shared<log_hourlyrollingfile>(logger_path, ztime, feature, max_line_, clean_time_);
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
            path logger_path = build_path(service_.c_str());
            logger_path.append(feature);
            auto ztime = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
            std::lock_guard<spin_mutex> lock(mutex_);
            if (rolling_type_ == DAYLY) {
                auto logfile = std::make_shared<log_dailyrollingfile>(logger_path, ztime, feature, max_line_, clean_time_);
                dest_lvls_.insert(std::make_pair(log_lvl, logfile));
            } else {
                auto logfile = std::make_shared<log_hourlyrollingfile>(logger_path, ztime, feature, max_line_, clean_time_);
                dest_lvls_.insert(std::make_pair(log_lvl, logfile));
            }
        }
        return true;
    }

    bool log_service::add_file_dest(cpchar feature, cpchar fname) {
        std::lock_guard<spin_mutex> lock(mutex_);
        if (!dest_features_.contains(feature)) {
            auto ztime = zoned_time(zone_, time_point_cast<milliseconds>(system_clock::now()));
            auto logfile = std::make_shared<log_file_base>(max_line_, ztime);
            path logger_path = build_path(service_.c_str());
            create_directories(logger_path);
            logfile->create(logger_path, fname);
            logfile->ignore_prefix(true);
            dest_features_.insert(std::make_pair(feature, logfile));
        }
        return true;
    }

    void log_service::del_agent(uint32_t tid) {
        std::lock_guard<spin_mutex> lock(mutex_);
        agents_.erase(tid);
    }

    void log_service::add_agent(sptr<log_agent> agent) {
        std::lock_guard<spin_mutex> lock(mutex_);
        agents_.insert(std::make_pair(agent->get_id(), agent));
    }

    void log_service::del_dest(cpchar feature) {
        std::lock_guard<spin_mutex> lock(mutex_);
        dest_features_.erase(feature);
    }

    void log_service::del_lvl_dest(log_level log_lvl) {
        std::lock_guard<spin_mutex> lock(mutex_);
        dest_lvls_.erase(log_lvl);
    }

    void log_service::set_dest_clean_time(cpchar feature, size_t clean_time){
        std::lock_guard<spin_mutex> lock(mutex_);
        if (auto it = dest_features_.find(feature); it != dest_features_.end()) {
            it->second->set_clean_time(clean_time);
        }
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
        thread_.join();
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
            for (auto [_, agent] : agents_) {
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
            flush();
            if (empty) {
                if (!running_) break;
                std::this_thread::sleep_for(milliseconds(50));
            }
        }
    }

    log_agent::log_agent() {
        logmsgque_ = std::make_shared<log_message_queue>();
        message_pool_ = std::make_shared<log_message_pool>();
    }

    log_agent::~log_agent() {
        if (auto service = service_.lock(); service) {
            service->del_agent(get_id());
        }
    }

    void log_agent::attach(wptr<log_service> service) { 
        service_ = service;
        if (auto lservice = service_.lock(); lservice) {
            lservice->add_agent(shared_from_this());
        }
    }

    void log_agent::output(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar source, int line) {
        if (!is_filter(level)) {
            auto logmsg_ = message_pool_->allocate();
            logmsg_->option(level, std::move(msg), tag, feature, source, line);
            logmsgque_->put(logmsg_);
        }
    }

    uint32_t log_agent::get_id() {
        auto tid = std::this_thread::get_id();
        return *(uint32_t*)&tid;
    }

    void log_agent::filter(log_level llv, bool on) {
        if (on)
            filter_bits_ |= (1 << ((int)llv - 1));
        else
            filter_bits_ &= ~(1 << ((int)llv - 1));
    }
}
