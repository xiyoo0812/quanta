#include <stdio.h>
#include <string.h>
#include "shm_channel.h"

#ifdef WIN32
#include <windows.h>
#else
#include <sys/ipc.h>
#include <sys/shm.h>
#include <sys/types.h>
#endif

namespace luabus {
    #define     MAGIN_LEN   64

#ifdef WIN32

    void* attach_shm(int shm_id, int size) {
        auto name = std::format("fm_{}", shm_id);
        HANDLE handle = OpenFileMapping(FILE_MAP_ALL_ACCESS, FALSE, name.c_str()); 
        if (!handle) handle = CreateFileMapping(INVALID_HANDLE_VALUE, 0, PAGE_READWRITE, 0, size, name.c_str());  
        if (!handle) return nullptr;
        auto buf = MapViewOfFile(handle, FILE_MAP_ALL_ACCESS, 0, 0, 0);  
        CloseHandle(handle);
        return buf;
    }

    void detach_shm(void* shm_buff) {
        UnmapViewOfFile(shm_buff);
    }

    void delete_shm(int shm_id){}
#else

    void* attach_shm(int shm_id, int size) {
        auto handle = shmget(shm_id, size, 0666);
        if (handle < 0) handle = shmget(shm_id, size, 0666 | IPC_CREAT);
        if (!handle) return nullptr;
        void* buf = shmat(handle, size, 0666);
        if(buf == (void*)-1) return nullptr;
        return buf;
    }

    void detach_shm(void* shm_buff) {
        shmdt(shm_buff);
    }

    void delete_shm(int shm_id) {
        auto handle = shmget(shm_id, size, flag);
        if (handle > 0) shmctl(handle, IPC_RMID, nullptr);	
    }
#endif

    schan_code shm_channel::init(int shm_key, uint32_t chan_size, bool binit) {
        if (chan_size == 0) return SHM_CHAN_ERR_INVALID;
        size_t shm_size = chan_size * 2 + sizeof(schan_header) + sizeof(shm_queue) * 2;
        char* shm_data = (char*)attach_shm(shm_key, shm_size);
        if (!shm_data) return SHM_CHAN_SHM_GET_FAIL;
        schan_header* shm_header = (schan_header*)shm_data;
        if (binit) {
            memset(shm_data, 0, shm_size);
            shm_header->sq_offset = sizeof(schan_header);
            shm_header->rq_offset = sizeof(schan_header) + sizeof(shm_queue) + chan_size;
            send_queue = (shm_queue*)(shm_data + shm_header->sq_offset);
            recv_queue = (shm_queue*)(shm_data + shm_header->rq_offset);
            send_queue->size = chan_size;
            recv_queue->size = chan_size;
        } else {
            send_queue = (shm_queue*)(shm_data + shm_header->sq_offset);
            recv_queue = (shm_queue*)(shm_data + shm_header->rq_offset);
        }
        return SHM_CHAN_SUCCCESS;
    }

    uint32_t shm_channel::get_used(shm_queue* queue)  {
        return (queue->head > queue->tail) ? (queue->size - queue->head + queue->tail) : (queue->tail - queue->head);
    }

    uint32_t shm_channel::get_free(shm_queue* queue)  {
        return (queue->head > queue->tail) ? (queue->head - queue->tail - 1) : (queue->head + queue->size - queue->tail - 1);
    }

    schan_code shm_channel::send(char* buf, uint32_t buf_size) {
        if (!send_queue) return SHM_CHAN_ERR_INVALID;
        uint32_t allsz = sizeof(uint32_t) + buf_size;
        uint32_t free = get_free(send_queue);
        if (free < allsz) return SHM_CHAN_ERR_FULL;
        uint32_t t = send_queue->tail;
        uint32_t tail_len = send_queue->size - t;
        uint32_t hdr = allsz;
        if (tail_len >= allsz) {
            memcpy(&send_queue->data[t], &hdr, sizeof(hdr));
            memcpy(&send_queue->data[t + sizeof(hdr)], buf, buf_size);
        } else if (tail_len >= sizeof(hdr)) {
            memcpy(&send_queue->data[t], &hdr, sizeof(hdr));
            uint32_t len1 = tail_len - sizeof(hdr);
            memcpy(&send_queue->data[t + sizeof(hdr)], buf, len1);
            uint32_t len2 = buf_size - len1;
            memcpy(&send_queue->data[0], buf + len1, len2);
        } else {
            memcpy(&send_queue->data[t], &hdr, tail_len);
            uint32_t len1 = sizeof(hdr) - tail_len;
            memcpy(&send_queue->data[0], ((char*)&hdr) + tail_len, len1);
            memcpy(&send_queue->data[len1], buf, buf_size);
        }
        t = (t + allsz) % send_queue->size;
        send_queue->tail = t;
        return SHM_CHAN_SUCCESS;
    }

    schan_code shm_channel::recv(char* buf, uint32_t* buf_size) {
        if (!recv_queue) return SHM_CHAN_ERR_INVALID;
        uint32_t h = recv_queue->head;
        uint32_t used = get_used(recv_queue);
        if (used == 0) return SHM_CHAN_ERR_EMPTY;
        if (used < sizeof(uint32_t)) return SHM_CHAN_ERR_HDR_EXCEED;
        uint32_t hdr = 0;
        if ((h + sizeof(hdr)) > recv_queue->size) {
            uint32_t len1 = recv_queue->size - h;
            memcpy(&hdr, &recv_queue->data[h], len1);
            uint32_t len2 = sizeof(hdr) - len1;
            memcpy(((char*)&hdr) + len1, &recv_queue->data[0], len2);
        } else {
            memcpy(&hdr, &recv_queue->data[h], sizeof(hdr));
        }
        h = (h + sizeof(hdr)) % recv_queue->size;
        uint32_t data_len = hdr - sizeof(hdr);
        if (data_len > (*buf_size)) return SHM_CHAN_ERR_NOT_ENOUGH;
        if (used < (sizeof(uint32_t) + data_len)) return SHM_CHAN_ERR_DATA_EXCEED;
        if ( (h + data_len) > recv_queue->size) {
            uint32_t len1 = recv_queue->size - h;
            memcpy(buf, &recv_queue->data[h], len1);
            uint32_t len2 = data_len - len1;
            memcpy(((char*)buf) + len1, &recv_queue->data[0], len2);
        } else {
            memcpy(buf, &recv_queue->data[h], data_len);
        }
        h = (h + data_len)%recv_queue->size;
        recv_queue->head = h;
        *buf_size = data_len;
        return SHM_CHAN_SUCCESS; 
    }

    void shm_channel::reset() {
        if (send_queue) send_queue->tail = send_queue->head = 0;
        if (recv_queue) recv_queue->tail = recv_queue->head = 0;
    }

    uint32_t shm_channel::get_send_size() {
        return send_queue ? send_queue->size : 0;
    }

    uint32_t shm_channel::get_resv_size() {
        return recv_queue ? recv_queue->size : 0;
    }
}