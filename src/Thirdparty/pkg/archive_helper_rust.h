/**
 * @file archive_helper_rust.h
 * @brief C ABI declarations for the Rust archive helper.
 */
#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PlayasaArchiveEntry {
  const wchar_t* ptr;
  size_t len;
} PlayasaArchiveEntry;

typedef struct PlayasaArchiveEntryList {
  PlayasaArchiveEntry* items;
  size_t len;
} PlayasaArchiveEntryList;

PlayasaArchiveEntryList playasa_archive_list_zip(const wchar_t* path);
void playasa_archive_free_entry_list(PlayasaArchiveEntryList list);

#ifdef __cplusplus
}
#endif
