#pragma once

#include <stdint.h>

namespace luabus {
    
    enum class schan_code : int8_t {
        SHM_CHAN_SUCCESS            = 0,
        SHM_CHAN_ERR_FULL           = -1,
        SHM_CHAN_ERR_EMPTY          = -2,
        SHM_CHAN_ERR_NOT_ENOUGH     = -3,
        SHM_CHAN_SHM_GET_FAIL       = -4,
        SHM_CHAN_Q0_INVALID         = -5,
        SHM_CHAN_Q1_INVALID         = -6,
        SHM_CHAN_ERR_HDR_EXCEED     = -7,
        SHM_CHAN_ERR_DATA_EXCEED    = -8,
        SHM_CHAN_ERR_INVALID        = -9,
    };
    using enum schan_code;

    typedef struct{
        uint32_t head;      //the position of the first item
        uint32_t tail;      //the position after last item
        uint32_t size;
        char data[0];
    } shm_queue;

    typedef struct {
        uint32_t sq_offset;
        uint32_t rq_offset;
    } schan_header;


    class  shm_channel{
    public:
        schan_code init(int shm_key, uint32_t chan_size, bool binit = false);
        schan_code recv(char* buf, uint32_t* buf_size);
        schan_code send(char* buf, uint32_t buf_size);

        void reset();
        
        uint32_t get_used(shm_queue* queue);
        uint32_t get_free(shm_queue* queue);

        uint32_t get_send_size();
        uint32_t get_resv_size();

    private:
        shm_queue* send_queue;
        shm_queue* recv_queue;
    };

    
}