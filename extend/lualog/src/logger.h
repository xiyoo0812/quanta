#pragma once

#include <list>
#include <array>
#include <ctime>
#include <mutex>
#include <vector>
#include <chrono>
#include <thread>
#include <sstream>
#include <fstream>
#include <iostream>
#include <filesystem>
#include <unordered_map>
#include <condition_variable>
#include <assert.h>

#ifdef WIN32
#include <process.h>
#define getpid _getpid
#else
#include <unistd.h>
#endif

enum class log_level
{
	LOG_LEVEL_DEBUG = 1,
	LOG_LEVEL_INFO,
	LOG_LEVEL_WARN,
	LOG_LEVEL_DUMP,
	LOG_LEVEL_ERROR,
};

enum class rolling_type
{
	HOURLY = 0,
	DAYLY = 1,
}; //rolling_type

template <typename T>
struct level_names {};

template <> struct level_names<log_level> {
	constexpr std::array<const char*, 6> operator()() const {
		return {
			"UNKNW",
			"DEBUG",
			"INFO",
			"WARN",
			"DUMP",
			"ERROR",
		};
	}
};

template <typename T>
struct level_colors {};
template <> struct level_colors<log_level> {
	constexpr std::array<const char*, 6> operator()() const {
		return {
			"\027[32m",
			"\027[37m",
			"\027[32m",
			"\027[33m",
			"\027[32m",
			"\027[31m",
		};
	}
};

class log_filter
{
public:
	void filter(log_level llv, bool on)
	{
		if (on)
			switch_bits_ |= (1 << ((int)llv - 1));
		else
			switch_bits_ &= ~(1 << ((int)llv - 1));
	}
	bool is_filter(log_level llv) const
	{
		return 0 == (switch_bits_ & (1 << ((int)llv - 1)));
	}
private:
	unsigned switch_bits_ = -1;
}; // class log_filter

class log_time : public ::tm
{
public:
	int tm_usec = 0;

	log_time() { }
	log_time(const ::tm & tm, int usec) : ::tm(tm), tm_usec(usec) { }
	static log_time now()
	{
		auto time_now = std::chrono::system_clock::now();
		auto duration_ms = std::chrono::duration_cast<std::chrono::milliseconds>(time_now.time_since_epoch());
		auto time_t = std::chrono::system_clock::to_time_t(time_now);
		return log_time(*std::localtime(&time_t), duration_ms.count() % 1000);
	}
}; // class log_time

template<log_level> class log_ctx;
class log_message
{
public:
	template<log_level> friend class log_ctx;

	int line() const { return line_; }
	log_level level() const { return level_; }
	const std::string msg() const { return stream_.str(); }
	const std::string source() const { return source_; }
	const log_time & get_log_time()const { return log_time_; }
	void clear() 
	{
		stream_.clear(); 
		stream_.str("");
	}
	template<class T>
	log_message& operator<<(const T & value)
	{
		stream_ << value;
		return *this;
	}
private:
	int					line_ = 0;
	log_time			log_time_;
	std::string			source_;
	std::stringstream	stream_;
	log_level			level_ = log_level::LOG_LEVEL_DEBUG;
}; // class log_message

class log_message_pool
{
public:
	log_message_pool(size_t msg_size)
	{
		for (size_t i = 0; i < msg_size; ++i)
		{
			messages_.push_back(std::make_shared<log_message>());
		}
	}
	~log_message_pool()
	{
		messages_.clear();
	}
	std::shared_ptr<log_message> allocate()
	{
		std::unique_lock<std::mutex> lock(mutex_);
		if (messages_.empty())
		{
			condv_.wait(lock);
		}
		auto logmsg = messages_.front();
		messages_.pop_front();
		logmsg->clear();
		return logmsg;
	}
	void release(std::shared_ptr<log_message> logmsg)
	{
		std::unique_lock<std::mutex> lock(mutex_);
		messages_.push_back(logmsg);
		condv_.notify_one();
	}

private:
	mutable std::mutex				mutex_;
	std::condition_variable			condv_;
	std::list<std::shared_ptr<log_message>>	messages_;
}; // class log_message_pool

class log_message_queue
{
public:
	void put(std::shared_ptr<log_message> logmsg)
	{
		std::unique_lock<std::mutex> lock(mutex_);
		messages_.push_back(logmsg);
		condv_.notify_all();
	}

	void timed_getv(std::vector<std::shared_ptr<log_message>>& vec_msg, size_t number, int time)
	{
		std::unique_lock<std::mutex>lock(mutex_);
		if (messages_.empty())
		{
			condv_.wait_for(lock, std::chrono::milliseconds(time));
		}
		while (!messages_.empty() && number > 0)
		{
			auto logmsg = messages_.front();
			vec_msg.push_back(logmsg);
			messages_.pop_front();
			number--;
		}
	}

private:
	std::mutex								mutex_;
	std::condition_variable					condv_;
	std::list<std::shared_ptr<log_message>> messages_;
}; // class log_message_queue

class log_service;
class log_dest
{
public:
	log_dest(std::shared_ptr<log_service>service)
		: log_service_(service)
	{
	}
	virtual ~log_dest() { }

	virtual void flush() = 0;
	virtual void raw_write(std::string msg, log_level lvl) = 0;
	virtual void write(std::shared_ptr<log_message> logmsg);
	virtual std::string build_prefix(std::shared_ptr<log_message> logmsg);
	virtual std::string build_postfix(std::shared_ptr<log_message> logmsg);

protected:
	std::shared_ptr<log_service>	log_service_ = nullptr;
}; // class log_dest


class stdio_dest : public log_dest
{
public:
	stdio_dest(std::shared_ptr<log_service> service)
		: log_dest(service) {}
	virtual ~stdio_dest() { }

	virtual void raw_write(std::string msg, log_level lvl)
	{
#ifdef WIN32
		auto colors = level_colors<log_level>()();
		std::cout << colors[(int)lvl];
#endif // WIN32
		auto names = level_colors<log_level>()();
		std::cout << msg;
	}
	virtual void flush() 
	{
		std::cout.flush();
	}
}; // class stdio_dest

class log_file_base : public log_dest
{
public:
	log_file_base(std::shared_ptr<log_service> service, size_t max_line)
		: log_dest(service)
		, max_line_(max_line)
	{
	}
	virtual ~log_file_base()
	{
		if (file_)
		{
			file_->flush();
			file_->close();
		}
	}
	virtual void raw_write(std::string msg, log_level lvl)
	{
		if (file_) file_->write(msg.c_str(), msg.size());
	}
	virtual void flush()
	{
		if (file_) file_->flush();
	}
	const log_time & file_time() const { return file_time_; }

protected:
	virtual void create(const std::string& file_path, const log_time& file_time, const char * mode)
	{
		if (file_)
		{
			file_->flush();
			file_->close();
		}
		file_name_ = file_path;
		file_time_ = file_time;
		file_ = std::make_unique<std::ofstream>(file_path, std::ios::binary | std::ios::out | std::ios::app);
	}

	size_t			line_;
	size_t			max_line_;
	log_time		file_time_;
	std::string		file_name_;
	std::unique_ptr<std::ofstream> file_ = nullptr;
}; // class log_file

class rolling_hourly
{
public:
	bool eval(const log_file_base* log_file, const std::shared_ptr<log_message> logmsg) const
	{
		const log_time & ftime = log_file->file_time();
		const log_time & ltime = logmsg->get_log_time();
		return ltime.tm_year != ftime.tm_year || ltime.tm_mon != ftime.tm_mon ||
			ltime.tm_mday != ftime.tm_mday || ltime.tm_hour != ftime.tm_hour;
	}

}; // class rolling_hourly

class rolling_daily
{
public:
	bool eval(const log_file_base* log_file, const std::shared_ptr<log_message> logmsg) const
	{
		const log_time & ftime = log_file->file_time();
		const log_time & ltime = logmsg->get_log_time();
		return ltime.tm_year != ftime.tm_year || ltime.tm_mon != ftime.tm_mon || ltime.tm_mday != ftime.tm_mday;
	}
}; // class rolling_daily

template<class rolling_evaler>
class log_rollingfile : public log_file_base
{
public:
	log_rollingfile(std::shared_ptr<log_service> service, const std::string& log_path, const std::string& log_name, size_t max_line = 10000)
		: log_file_base(service, max_line)
		, log_name_(log_name)
		, log_path_(log_path)
	{
		std::filesystem::create_directories(log_path_);
	}

	virtual void write(std::shared_ptr<log_message> logmsg)
	{
		line_++;
		if (rolling_evaler_.eval(this, logmsg) || line_ >= max_line_)
		{
			std::string file_path = new_log_file_path(logmsg);
			create(file_path, logmsg->get_log_time(), "a+");
			assert(file_);
			line_ = 0;
		}
		log_file_base::write(logmsg);
	}

protected:
	std::string new_log_file_path(const std::shared_ptr<log_message> logmsg)
	{
		char buf[64];
		const log_time& ltime = logmsg->get_log_time();
		snprintf(buf, sizeof(buf), "%s-%04d%02d%02d-%02d%02d%02d.%03d.p%d.log", log_name_.c_str(),
			ltime.tm_year + 1900, 
			ltime.tm_mon + 1,
			ltime.tm_mday,
			ltime.tm_hour,
			ltime.tm_min,
			ltime.tm_sec,
			ltime.tm_usec,
			log_service_->get_pid()
		);
		return log_path_.string() + std::string(buf);
	}

	std::string				log_name_;
	std::filesystem::path	log_path_;
	rolling_evaler			rolling_evaler_;
}; // class log_rollingfile

typedef log_rollingfile<rolling_hourly> log_hourlyrollingfile;
typedef log_rollingfile<rolling_daily> log_dailyrollingfile;

class log_service
{
public:
	~log_service()
	{
		stop();
	}
	int get_pid() { return log_pid_; }
	void daemon(bool status) { log_daemon_ = status; }
	std::shared_ptr<log_filter> get_filter() { return log_filter_; }
	std::shared_ptr<log_message_pool> message_pool() { return message_pool_; }

	bool add_dest(std::string log_path, std::string log_name, rolling_type roll_type, size_t max_line)
	{
		std::unique_lock<std::mutex> lock(mutex_);
		if (dest_names_.find(log_name) == dest_names_.end())
		{
			auto share_this = default_instance();
			if (roll_type == rolling_type::DAYLY)
			{
				auto logfile = std::make_shared<log_hourlyrollingfile>(share_this, log_path, log_name, max_line);
				dest_names_.insert(std::make_pair(log_name, logfile));
			}
			else 
			{
				auto logfile = std::make_shared<log_hourlyrollingfile>(share_this, log_path, log_name, max_line);
				dest_names_.insert(std::make_pair(log_name, logfile));
			}
			return true;
		}
		return false;
	}

	bool add_level_dest(std::string log_path, std::string log_name, log_level log_lvl, rolling_type roll_type, size_t max_line)
	{
		std::unique_lock<std::mutex> lock(mutex_);
		auto share_this = default_instance();
		if (roll_type == rolling_type::DAYLY)
		{
			auto logfile = std::make_shared<log_hourlyrollingfile>(share_this, log_path, log_name, max_line);
			dest_lvls_.insert(std::make_pair(log_lvl, logfile));
		}
		else
		{
			auto logfile = std::make_shared<log_hourlyrollingfile>(share_this, log_path, log_name, max_line);
			dest_lvls_.insert(std::make_pair(log_lvl, logfile));
		}
		return true;
	}

	void del_dest(std::string log_name)
	{
		std::unique_lock<std::mutex> lock(mutex_);
		auto it = dest_names_.find(log_name);
		if (it != dest_names_.end())
		{
			dest_names_.erase(it);
		}
	}

	void del_lvl_dest(log_level log_lvl)
	{
		std::unique_lock<std::mutex> lock(mutex_);
		auto it = dest_lvls_.find(log_lvl);
		if (it != dest_lvls_.end())
		{
			dest_lvls_.erase(it);
		}
	}

	void start(const std::string& log_path, const std::string& log_name, rolling_type roll_type = rolling_type::HOURLY, size_t max_line = 10000)
	{
		if (log_pid_ == 0)
		{
			log_pid_ = ::getpid();
			auto share_this = default_instance();
			log_filter_ = std::make_shared<log_filter>();
			message_pool_ = std::make_shared<log_message_pool>(3000);
			std_dest_ = std::make_shared<stdio_dest>(share_this);
			add_dest(log_path, log_name, roll_type, max_line);
			stop_msg_ = message_pool_->allocate();
			std::thread(_worker(share_this)).swap(thread_);
		}
	}

	void stop()
	{
		if (thread_.joinable())
		{
			logmsgque_.put(stop_msg_);
			thread_.join();
		}
	}

	void submit(std::shared_ptr<log_message> logmsg)
	{
		logmsgque_.put(logmsg);
	}

	void flush()
	{
		std::unique_lock<std::mutex> lock(mutex_);
		std_dest_->flush();
		for (auto dest : dest_names_)
			dest.second->flush();
		for (auto dest : dest_lvls_)
			dest.second->flush();
	}

	bool is_ignore_prefix() const { return ignore_prefix_; }
	bool is_ignore_postfix() const { return ignore_postfix_; }
	void ignore_prefix() { ignore_prefix_ = true; }
	void ignore_postfix() { ignore_postfix_ = true; }

	static std::shared_ptr<log_service> default_instance()
	{
		static auto _service = std::make_shared<log_service>();
		return _service;
	}

private:
	struct _worker
	{
		std::shared_ptr<log_service> service;
		_worker(std::shared_ptr<log_service> _service)
			: service(_service)
		{
		}
		void operator()()
		{
			service->run();
		}
	}; // struct _worker
	friend struct _worker;

	void run()
	{
		bool loop = true;
		while (loop)
		{
			std::vector<std::shared_ptr<log_message>> logmsgs;
			logmsgque_.timed_getv(logmsgs, log_getv_, log_period_);
			for (auto logmsg : logmsgs)
			{
				if (logmsg == stop_msg_)
				{
					loop = false;
					continue;
				}
				if (!log_filter_->is_filter(logmsg->level()))
				{
					if (!log_daemon_)
					{
						std_dest_->write(logmsg);
					}
					auto iter = dest_lvls_.find(logmsg->level());
					if (iter != dest_lvls_.end())
					{
						iter->second->write(logmsg);
					}
					else
					{
						for (auto dest : dest_names_)
						{
							dest.second->write(logmsg);
						}
					}
				}
				message_pool_->release(logmsg);
			}
			flush();
		}
	}

	std::mutex							mutex_;
	std::thread							thread_;
	log_message_queue					logmsgque_;
	std::shared_ptr<log_filter>			log_filter_;
	std::shared_ptr<log_message>		stop_msg_ = nullptr;
	std::shared_ptr<log_message_pool>	message_pool_ = nullptr;
	std::shared_ptr<log_dest>			std_dest_ = nullptr;
	std::unordered_map<log_level, std::shared_ptr<log_dest>> dest_lvls_;
	std::unordered_map<std::string, std::shared_ptr<log_dest>> dest_names_;
	int									log_pid_ = 0;
	int									log_getv_ = 100;
	int									log_period_ = 10;
	bool								log_daemon_ = false;
	bool								ignore_postfix_ = true;
	bool								ignore_prefix_ = false;
}; // class log_service

inline void log_dest::write(std::shared_ptr<log_message> logmsg)
{
	std::string profix = build_prefix(logmsg);
	std::string postfix = build_postfix(logmsg);
	raw_write(profix + logmsg->msg() + postfix + "\n", logmsg->level());
}

inline std::string log_dest::build_prefix(std::shared_ptr<log_message> logmsg)
{
	char date_ch[64] = { 0 };
	if (!log_service_->is_ignore_prefix())
	{
		auto names = level_names<log_level>()();
		const log_time& ltime = logmsg->get_log_time();
		snprintf(date_ch, sizeof(date_ch), "%04d%02d%02d %02d:%02d:%02d.%03d/%s ",
			ltime.tm_year + 1900,
			ltime.tm_mon + 1,
			ltime.tm_mday,
			ltime.tm_hour,
			ltime.tm_min,
			ltime.tm_sec,
			ltime.tm_usec,
			names[(int)logmsg->level()]
		);
	}
	return date_ch;
}

inline std::string log_dest::build_postfix(std::shared_ptr<log_message> logmsg)
{
	char date_ch[280] = { 0 };
	if (!log_service_->is_ignore_postfix())
	{
		snprintf(date_ch, sizeof(date_ch), " [%s:%d]", logmsg->source().c_str(), logmsg->line());
	}
	return date_ch;
}

template<log_level level>
class log_ctx
{
public:
	log_ctx(std::shared_ptr<log_service> service, const std::string source = "", int line = 0)
		: service_(service)
	{
		logmsg_ = service->message_pool()->allocate();
		logmsg_->log_time_ = log_time::now();
		logmsg_->level_ = level;
		logmsg_->source_ = source;
		logmsg_->line_ = line;
	}
	~log_ctx()
	{
		service_->submit(logmsg_);
	}

	template<class T>
	log_ctx & operator<<(const T& value)
	{
		*logmsg_ << value;
		return *this;
	}

private:
	std::shared_ptr<log_message> logmsg_;
	std::shared_ptr<log_service> service_;
};
