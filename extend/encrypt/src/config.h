#pragma once

#define ENCRYPT_BUILD_EXPORT_TO_LUA 1  

#ifdef _WIN32
    #define ENCRYPT_API  __declspec (dllexport)
#else
    #define ENCRYPT_API 
#endif
