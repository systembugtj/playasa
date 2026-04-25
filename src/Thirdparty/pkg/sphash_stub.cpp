/**
 * @file sphash_stub.cpp
 * @brief 无 sphash.lib 时的占位实现：不读盘不算摘要，与调用方“len==0 视为失败”逻辑一致。
 */
#include "sphash.h"

void hash_file(const char* mod, int algo, const wchar_t* path, char* out, int* len) {
  (void)mod;
  (void)algo;
  (void)path;
  if (out) {
    out[0] = '\0';
  }
  if (len) {
    *len = 0;
  }
}

void hash_data(const char* mod, int algo, char* buff, int* len) {
  (void)mod;
  (void)algo;
  (void)buff;
  if (len) {
    *len = 0;
  }
}
