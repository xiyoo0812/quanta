#include "stdafx.h"
#include "shm_channel.h"

#ifdef WIN32
#include <windows.h>
#else
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#endif

namespace luabus {

    void* attach_shm(uint64_t shm_id, int size) {
        auto name = std::format("/{}", shm_id);
#ifdef WIN32
        HANDLE handle = OpenFileMapping(FILE_MAP_ALL_ACCESS, FALSE, name.c_str()); 
        if (!handle) handle = CreateFileMapping(INVALID_HANDLE_VALUE, 0, PAGE_READWRITE, 0, size, name.c_str());  
        if (!handle) return nullptr;
        auto buf = MapViewOfFile(handle, FILE_MAP_ALL_ACCESS, 0, 0, 0);  
        CloseHandle(handle);
#else
        int shm_fd = shm_open(name.c_str(), O_CREAT | O_RDWR, 0777);
        if (shm_fd < 0) return nullptr;
        ftruncate(shm_fd, size);
        auto buf = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_SHARED, shm_fd, 0);
        close(shm_fd);
#endif
        return buf;
    }

    void detach_shm(void* shm_buff, int size) {
#ifdef WIN32
        UnmapViewOfFile(shm_buff);
#else
        munmap(shm_buff, int size);
#endif
    }

    void delete_shm(uint64_t shm_id){
#ifndef WIN32
        auto name = std::format("/{}", shm_id);
        shm_unlink(name.c_str());
#endif
    }

    chan_code shm_channel::init(uint64_t shm_id, uint32_t chan_size, uint32_t id) {
        if (chan_size == 0) return CHAN_ERR_INVALID;
        size_t shm_size = chan_size * 2 + sizeof(schan_header) + sizeof(shm_queue) * 2;
        char* shm_data = (char*)attach_shm(shm_id, shm_size);
        if (!shm_data) return CHAN_SHM_GET_FAIL;
        auto now = luakit::now();
        schan_header* header = (schan_header*)shm_data;
        if (now - header->time > 60) {
            memset(shm_data, 0, shm_size);
            header->time = now;
            header->offset1 = sizeof(schan_header);
            header->offset2 = sizeof(schan_header) + sizeof(shm_queue) + chan_size;
            send_queue = (shm_queue*)(shm_data + ((shm_id & 0xffffffff) == id) ? header->offset1 : header->offset2);
            recv_queue = (shm_queue*)(shm_data + ((shm_id & 0xffffffff) == id) ? header->offset2 : header->offset1);
            send_queue->size = chan_size;
            recv_queue->size = chan_size;
        } else {
            send_queue = (shm_queue*)(shm_data + ((shm_id & 0xffffffff) == id) ? header->offset1 : header->offset2);
            recv_queue = (shm_queue*)(shm_data + ((shm_id & 0xffffffff) == id) ? header->offset2 : header->offset1);
        }
        return CHAN_SUCCESS;
    }

    uint32_t shm_channel::get_used(size_t head, size_t tail, uint32_t size) {
        return (head > tail) ? (size - head + tail) : (tail - head);
    }

    uint32_t shm_channel::get_free(size_t head, size_t tail, uint32_t size)  {
        return (head > tail) ? (head - tail - 1) : (head + size - tail - 1);
    }

    chan_code shm_channel::send(char* buf, uint32_t buf_size) {
        if (!send_queue) return CHAN_ERR_INVALID;
        size_t tail = send_queue->tail.load(std::memory_order_acquire);
        size_t head = send_queue->head.load(std::memory_order_acquire);
        uint32_t free = get_free(head, tail, send_queue->size);
        if (free < buf_size) return CHAN_ERR_FULL;
        uint32_t tail_len = send_queue->size - tail;
        if (tail_len >= buf_size) {
            memcpy(&send_queue->data[tail], buf, buf_size);
        } else {
            memcpy(&send_queue->data[tail], buf, tail_len);
            memcpy(&send_queue->data[0], buf + tail_len, buf_size - tail_len);
        }
        tail = (tail + buf_size) % send_queue->size;
        send_queue->tail.store(tail, std::memory_order_acquire);
        return CHAN_SUCCESS;
    }

    chan_code shm_channel::recv(char* buf, uint32_t* buf_size) {
        if (!recv_queue) return CHAN_ERR_INVALID;
        size_t tail = recv_queue->tail.load(std::memory_order_acquire);
        size_t head = recv_queue->head.load(std::memory_order_acquire);
        uint32_t used = get_used(head, tail, recv_queue->size);
        if (used == 0) return CHAN_ERR_EMPTY;
        buf = &recv_queue->data[head];
        if (tail > head) {
            auto size = (used > *buf_size) ? *buf_size : used;
            recv_queue->head.store(head + size, std::memory_order_acquire);
            *buf_size = size;
        } else {
            *buf_size = recv_queue->size - tail;
            recv_queue->head.store(0, std::memory_order_acquire);
        }
        return CHAN_SUCCESS; 
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