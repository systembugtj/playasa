/**
 * @file sphash.h
 * @brief 与旧 sphash 库兼容的声明；实现见 sphash_stub.cpp（无厂商库时占位）。
 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define HASH_MOD_VIDEO_STR "video"
#define HASH_MOD_FILE_STR "file"
#define HASH_MOD_BINARY_STR "binary"

#define HASH_ALGO_MD5 0

void hash_file(const char* mod, int algo, const wchar_t* path, char* out, int* len);
void hash_data(const char* mod, int algo, char* buff, int* len);

#ifdef __cplusplus
}
#endif
