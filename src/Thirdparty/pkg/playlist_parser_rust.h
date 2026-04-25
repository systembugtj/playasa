/**
 * @file playlist_parser_rust.h
 * @brief C ABI for Rust playlist parser modules.
 */
#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct PlayasaPlaylistPath {
  const wchar_t* ptr;
  size_t len;
} PlayasaPlaylistPath;

typedef struct PlayasaPlaylistPathList {
  PlayasaPlaylistPath* items;
  size_t len;
} PlayasaPlaylistPathList;

PlayasaPlaylistPathList playasa_playlist_parse_cue(const wchar_t* path);
void playasa_playlist_free_path_list(PlayasaPlaylistPathList list);

#ifdef __cplusplus
}
#endif
