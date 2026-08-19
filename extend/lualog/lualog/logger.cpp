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
    void log_message::option(log_level lvl, sstring&& msg, cpchar tag, cpchar feature, cpchar trace_id) {
        tag_ = tag;
        level_ = lvl;
        feature_ = feature;
        trace_id_ = trace_id;
        time_ = system_clock::now();
        msg_ = std::move(msg);
    }

    void log_message::format(pchar secbuf, seconds& last) {
        auto point = time_.time_since_epoch();
        if (auto now = duration_cast<seconds>(point); now != last) {
            format_time(secbuf, "%Y-%m-%d %H:%M:%S", time_);
            last = now;
        }
        auto lvn = level_names[(int)level_];
        uint32_t ms = duration_cast<milliseconds>(point).count() % 1000;
        if (trace_id_.empty()) {
            msg_ = std::format("[{}.{:03}][{}][{}] {}\n", secbuf, ms, tag_, lvn, msg_);
        } else {
            msg_ = std::format("[{}.{:03}][{}][{}][T-{}] {}\n", secbuf, ms, tag_, lvn, trace_id_, msg_);
        }
    }

    // class log_message_queue
    // --------------------------------------------------------------------------------
    log_message* log_message_queue::allocate() {
        size_t tail = tail_.load(std::memory_order_relaxed);
        size_t head = head_.load(std::memory_order_acquire);
        if (tail - head >= QUEUE_SIZE) return nullptr;
        return &msgs_[tail % QUEUE_SIZE];
    }

    void log_message_queue::commit() {
        tail_.fetch_add(1, std::memory_order_release);
    }

    bool log_message_queue::empty() const {
        size_t tail = tail_.load(std::memory_order_acquire);
        size_t head = head_.load(std::memory_order_relaxed);
        return head == tail;
    }
    
    size_t log_message_queue::size() const {
        size_t tail = tail_.load(std::memory_order_acquire);
        size_t head = head_.load(std::memory_order_relaxed);
        return tail - head;
    }

    bool log_message_queue::full() const {
        size_t tail = tail_.load(std::memory_order_acquire);
        size_t head = head_.load(std::memory_order_relaxed);
        return (tail - head + 1) % QUEUE_SIZE == tail;
    }

    log_message* log_message_queue::pop() {
        size_t head = head_.load(std::memory_order_relaxed);
        size_t tail = tail_.load(std::memory_order_acquire);
        if (head == tail) return nullptr;
        log_message* logmsg = &msgs_[head % QUEUE_SIZE];
        head_.fetch_add(1, std::memory_order_release);
        return logmsg;
    }

    // class log_dest
    // --------------------------------------------------------------------------------
    void log_dest::write(log_message* msg) {
        line_++;
        if (!output_) {
            raw_write(msg);
            return;
        }
        auto data = msg->data();
        output_(data.data(), data.size(), msg->level());
    }

    // class stdio_dest
    // --------------------------------------------------------------------------------
    void stdio_dest::raw_write(log_message* msg) {
#ifdef WIN32
        std::cout << level_colors[msg->level()] << msg->data() << "\x1b[0m";
#else
        std::cout << msg->data();
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

    void log_file_base::raw_write(log_message* msg) {
        auto data = msg->data();
        auto size = data.size();
        if (size_ + size >= USHRT_MAX) flush();
        if (size >= USHRT_MAX) {
            file_->write(data.data(), size);
            return;
        }
        memcpy(log_buf_ + size_, data.data(), size);
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
        std::unique_lock lock(mutex_);
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

    bool log_service::add_lvl_dest(size_t log_lvl) {
        if (!dest_lvls_.contains(log_lvl)) {
            sstring feature = level_names[(int)log_lvl];
            std::transform(feature.begin(), feature.end(), feature.begin(), [](auto c) { return std::tolower(c); });
            fspath logger_path = build_path(service_.c_str());
            logger_path.append(feature);
            std::unique_lock lock(mutex_);
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
        std::unique_lock lock(mutex_);
        if (!dest_features_.contains(feature)) {
            try {
                fspath logger_path = build_path(service_.c_str());
                create_directories(logger_path);
                auto logfile = std::make_shared<log_file_base>(max_line_);
                logfile->create(logger_path, fname);
                dest_features_.insert(std::make_pair(feature, logfile));
            } catch (...) {}
        }
        return true;
    }

    void log_service::del_agent(log_agent* agent) {
        std::unique_lock lock(mutex_);
        agents_.erase(agent);
    }

    void log_service::add_agent(log_agent* agent) {
        std::unique_lock lock(mutex_);
        agents_.emplace(agent);
    }

    void log_service::del_dest(cpchar feature) {
        std::unique_lock lock(mutex_);
        dest_features_.erase(feature);
    }

    void log_service::del_lvl_dest(size_t log_lvl) {
        std::unique_lock lock(mutex_);
        dest_lvls_.erase(log_lvl);
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
            std::shared_lock lock(mutex_);
            for (auto& agent : agents_) {
                while (!agent->empty()) {
                    auto logmsg = agent->get_message();
                    if (log_std_) std_dest_->write(logmsg);
                    if (auto it = dest_features_.find(logmsg->feature()); it != dest_features_.end()) {
                        it->second->write(logmsg);
                        continue;
                    }
                    if (auto it = dest_lvls_.find(logmsg->level()); it != dest_lvls_.end()) {
                        it->second->write(logmsg);
                    }
                    main_dest_->write(logmsg);
                    empty = false;
                }
            }
            if (empty) {
                if (!running_) break;
                std::unique_lock<std::mutex> lock(cvmutex_);
                cv_.wait_for(lock, milliseconds(50));
                flush();
            }
        }
    }

    log_agent::log_agent() {
        logmsgque_ = std::make_shared<log_message_queue>();
    }

    log_agent::~log_agent() {
        if (auto service = service_.lock(); service) {
            service->del_agent(this);
        }
    }

    log_message* log_agent::get_message() {
        auto message = logmsgque_->pop();
        if (message) {
            message->format(time_buf_, last_time_);
        }
        return message;
    }

    void log_agent::attach(wptr<log_service> service) {
        service_ = service;
        if (auto lservice = service_.lock(); lservice) {
            lservice->add_agent(this);
        }
    }

    void log_agent::output(log_level level, sstring&& msg, cpchar tag, cpchar feature, cpchar trace_id) {
        if (!is_filter(level)) {
            auto logmsg_ = logmsgque_->allocate();
            if (logmsg_){
                logmsg_->option(level, std::move(msg), tag, feature, trace_id);
                logmsgque_->commit();
                service_.lock()->notify_one();
            }
        }
    }

    void log_agent::filter(log_level llv, bool on) {
        if (on) filter_bits_ |= (1 << ((int)llv - 1));
        else filter_bits_ &= ~(1 << ((int)llv - 1));
    }
}
