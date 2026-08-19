#pragma once

namespace luakit {

    template <size_t CAPACITY = 8192>
    class spscbuff {
    public:
        spscbuff() : mask_(CAPACITY - 1) {
            write_idx_.store(0, std::memory_order_relaxed);
            read_idx_.store(0, std::memory_order_relaxed);
        }

        spscbuff(const spscbuff&) = delete;
        spscbuff& operator=(const spscbuff&) = delete;

        bool empty() { return size() == 0; }
        constexpr size_t capacity() { return CAPACITY; }

        size_t peek(uint8_t* data, size_t len) {
            size_t read  = read_idx_.load(std::memory_order_relaxed);
            size_t write = write_idx_.load(std::memory_order_acquire);
            size_t used  = write - read;
            if (used < len) return 0;
            return copy_from_buffer(data, read, len);
        }

        virtual bool push(const uint8_t* src, size_t len) { 
            size_t write = write_idx_.load(std::memory_order_relaxed);
            size_t read  = read_idx_.load(std::memory_order_acquire);
            if (CAPACITY - (write - read) < len) return false;
            copy_to_buffer(src, write, len);
            write_idx_.fetch_add(len, std::memory_order_release);
            return true;
        }

        bool pop(uint8_t* dst, size_t len = 0) {
            size_t read  = read_idx_.load(std::memory_order_relaxed);
            size_t write = write_idx_.load(std::memory_order_acquire);
            if (write - read < len) return false;
            copy_from_buffer(dst, read, len);
            read_idx_.fetch_add(len, std::memory_order_release);
            return true;
        }

        size_t size() {
            size_t write = write_idx_.load(std::memory_order_acquire);
            size_t read  = read_idx_.load(std::memory_order_relaxed);
            return write - read;
        }

        void reset() {
            write_idx_.store(0, std::memory_order_relaxed);
            read_idx_.store(0, std::memory_order_relaxed);
        }

    protected:
        size_t mask_;
        uint8_t buffer_[CAPACITY];
        alignas(64) std::atomic<size_t> write_idx_;
        alignas(64) std::atomic<size_t> read_idx_;

        void copy_to_buffer(const uint8_t* src, size_t idx, size_t len) {
            size_t start = idx & mask_;
            size_t first = std::min(len, CAPACITY - start);
            memcpy(buffer_ + start, src, first);
            if (first < len) {
                memcpy(buffer_, src + first, len - first);
            }
        }

        size_t copy_from_buffer(uint8_t* dst, size_t idx, size_t len) {
            size_t start = idx & mask_;
            size_t first = std::min(len, CAPACITY - start);
            memcpy(dst, buffer_ + start, first);
            if (first < len) {
                memcpy(dst + first, buffer_, len - first);
            }
            return len;
        }
    };

    template <size_t CAPACITY = 8192>
    class mpscbuff : public spscbuff<CAPACITY> {
    public:
        mpscbuff() {
            reserve_idx_.store(0, std::memory_order_relaxed);
        }

        bool push(const uint8_t* src, size_t len) {
            if (len > CAPACITY) return false;
            size_t ticket, read;
            while (true) {
                ticket = this->reserve_idx_.load(std::memory_order_relaxed);
                read = this->read_idx_.load(std::memory_order_acquire);
                if (ticket - read + len > CAPACITY) {
                    return false; 
                }
                if (this->reserve_idx_.compare_exchange_weak(ticket, ticket + len, 
                        std::memory_order_relaxed, std::memory_order_relaxed)) {
                    break; 
                }
            }
            this->copy_to_buffer(src, ticket, len);
            while (this->write_idx_.load(std::memory_order_acquire) != ticket) {
                std::this_thread::yield(); 
            }
            this->write_idx_.store(ticket + len, std::memory_order_release);
            return true;
        }

        void reset() {
            spscbuff<CAPACITY>::reset();
            reserve_idx_.store(0, std::memory_order_relaxed);
        }

    private:
        alignas(64) std::atomic<size_t> reserve_idx_; 
    };
}
