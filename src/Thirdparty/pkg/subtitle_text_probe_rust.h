/**
 * @file subtitle_text_probe_rust.h
 * @brief C ABI declarations for the Rust subtitle text probe.
 */
#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define PLAYASA_SUBTITLE_ENCODING_UNKNOWN 0
#define PLAYASA_SUBTITLE_ENCODING_UTF8 1
#define PLAYASA_SUBTITLE_ENCODING_UTF8_BOM 2
#define PLAYASA_SUBTITLE_ENCODING_UTF16_LE 3
#define PLAYASA_SUBTITLE_ENCODING_UTF16_BE 4

#define PLAYASA_SUBTITLE_FORMAT_UNKNOWN 0
#define PLAYASA_SUBTITLE_FORMAT_SRT 1
#define PLAYASA_SUBTITLE_FORMAT_ASS_SSA 2
#define PLAYASA_SUBTITLE_FORMAT_WEBVTT 3

typedef struct PlayasaSubtitleTextProbe {
  int encoding;
  int format_hint;
  int confidence;
} PlayasaSubtitleTextProbe;

PlayasaSubtitleTextProbe playasa_subtitle_probe_text(const wchar_t* path);

#ifdef __cplusplus
}
#endif
