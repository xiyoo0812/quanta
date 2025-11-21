#pragma once

#include <atomic>
#include <stdint.h>

namespace luabus {
   
    enum class chan_code : int8_t {
        CHAN_SUCCESS            = 0,
        CHAN_ERR_FULL           = -1,
        CHAN_ERR_EMPTY          = -2,
        CHAN_ERR_NOT_ENOUGH     = -3,
        CHAN_SHM_GET_FAIL       = -4,
        CHAN_ERR_HDR_EXCEED     = -7,
        CHAN_ERR_DATA_EXCEED    = -8,
        CHAN_ERR_INVALID        = -9,
    };
    using enum chan_code;

    typedef struct{
        alignas(64) std::atomic<size_t> head;
        alignas(64) std::atomic<size_t> tail;
        uint32_t size;
        char data[0];
    } shm_queue;

    typedef struct {
        uint32_t offset1;
        uint32_t offset2;
        size_t time;
    } schan_header;


    class  shm_channel{
    public:
        chan_code init(uint64_t shm_key, uint32_t chan_size, uint32_t id);
        chan_code recv(char* buf, uint32_t* buf_size);
        chan_code send(char* buf, uint32_t buf_size);

        void reset();
        
        uint32_t get_used(size_t head, size_t tail, uint32_t size);
        uint32_t get_free(size_t head, size_t tail, uint32_t size);

        uint32_t get_send_size();
        uint32_t get_resv_size();

    private:
        shm_queue* send_queue;
        shm_queue* recv_queue;
    };

    
}