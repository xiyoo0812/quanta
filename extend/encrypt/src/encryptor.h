#pragma once

#include "internal/config.h"
#include <cstdint>
#include <vector>

class ENCRYPT_API encryptor
{
    // type traits
public:
    class bytes_t final
    {
    public:
        bytes_t(uint8_t* ptr = NULL, size_t len = 0) : _data_ptr(NULL), _data_len(0)
        {
            if (NULL == ptr || 0 == len)
                return;

            _data_len = len;
            _data_ptr = new uint8_t[_data_len];
            memcpy(_data_ptr, ptr, _data_len);
        }
        
        bytes_t(const bytes_t& other) : _data_ptr(NULL), _data_len(0)
        {
            if (other.size() == 0)
                return;

            _data_len = other._data_len;
            _data_ptr = new uint8_t[_data_len];
            memcpy(_data_ptr, other._data_ptr, _data_len);
        }

        bytes_t(bytes_t&& other) : _data_ptr(other._data_ptr), _data_len(other._data_len)
        {
            other._data_ptr = NULL;
            other._data_len = 0;
        }

        bytes_t& operator = (bytes_t&& other)
        {
            clear();
            _data_ptr = other._data_ptr;
            _data_len = other._data_len;
            other._data_ptr = NULL;
            other._data_len = 0;

            return *this;
        }

        ~bytes_t()
        {
            if (NULL != _data_ptr)
            {
                delete[] _data_ptr;
                _data_ptr = NULL;
                _data_len = 0;
            }
        }
        
        void attach(uint8_t* ptr, size_t len)
        {
            _data_ptr = ptr;
            _data_len = len;
        }

        void dettach()
        {
            _data_ptr = NULL;
            _data_len = 0;
        }

        uint8_t* data() const
        {
            return _data_ptr;
        }

        size_t size() const
        {
            return _data_len;
        }

        void assign(uint8_t* ptr, size_t len)
        {
            if (NULL == ptr || 0 == len)
                return;

            _data_len = len;
            _data_ptr = new uint8_t[_data_len];
            memcpy(_data_ptr, ptr, _data_len);
        }

        void clear()
        {
            if (NULL != _data_ptr)
            {
                delete[] _data_ptr;
                _data_ptr = NULL;
                _data_len = 0;
            }
        }

    protected:
        uint8_t* _data_ptr;
        size_t   _data_len;
    };
public:
    encryptor();
    virtual ~encryptor();

    static bytes_t encrypt(uint8_t* data_ptr, size_t data_len);
    static bytes_t decrypt(uint8_t* data_ptr, size_t data_len);

    static bytes_t quick_zip(uint8_t* data_ptr, size_t data_len);
    static bytes_t quick_unzip(uint8_t* data_ptr, size_t data_len);
};