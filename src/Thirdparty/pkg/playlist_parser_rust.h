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

enum {
  PLAYASA_MPC_KEY_TYPE = 1,
  PLAYASA_MPC_KEY_LABEL = 2,
  PLAYASA_MPC_KEY_FILENAME = 3,
  PLAYASA_MPC_KEY_SUBTITLE = 4,
  PLAYASA_MPC_KEY_VIDEO = 5,
  PLAYASA_MPC_KEY_AUDIO = 6,
  PLAYASA_MPC_KEY_VINPUT = 7,
  PLAYASA_MPC_KEY_VCHANNEL = 8,
  PLAYASA_MPC_KEY_AINPUT = 9,
  PLAYASA_MPC_KEY_COUNTRY = 10
};

typedef struct PlayasaMpcPlaylistField {
  int index;
  int key;
  const wchar_t* ptr;
  size_t len;
  long long number;
} PlayasaMpcPlaylistField;

typedef struct PlayasaMpcPlaylistFieldList {
  PlayasaMpcPlaylistField* items;
  size_t len;
} PlayasaMpcPlaylistFieldList;

PlayasaPlaylistPathList playasa_playlist_parse_cue(const wchar_t* path);
PlayasaPlaylistPathList playasa_playlist_parse_m3u(const wchar_t* path);
PlayasaPlaylistPathList playasa_playlist_parse_pls(const wchar_t* path);
PlayasaMpcPlaylistFieldList playasa_playlist_parse_mpc(const wchar_t* path);
void playasa_playlist_free_path_list(PlayasaPlaylistPathList list);
void playasa_playlist_free_mpc_field_list(PlayasaMpcPlaylistFieldList list);

#ifdef __cplusplus
}
#endif
