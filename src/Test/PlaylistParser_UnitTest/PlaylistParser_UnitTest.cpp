// PlaylistParser_UnitTest.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include "../../Source/apps/mplayerc/Model/PlaylistParserRust.h"
#include "../../Thirdparty/pkg/archive_helper_rust.h"
#include "../../Thirdparty/pkg/subtitle_text_probe_rust.h"

namespace {

const wchar_t kCueFileName[] = L"album.cue";
const wchar_t kMediaFileName[] = L"Track 01.flac";
const wchar_t kCueText[] = L"FILE \"Track 01.flac\" WAVE\r\n";
const wchar_t kMpcFileName[] = L"playlist.mpcpl";
const wchar_t kMpcMediaFileName[] = L"movie.mp4";
const wchar_t kMpcSubtitleFileName[] = L"movie.srt";
const wchar_t kMpcText[] =
    L"MPCPLAYLIST\r\n"
    L"2,type,0\r\n"
    L"2,label,Rust MPC item\r\n"
    L"2,filename,movie.mp4\r\n"
    L"2,subtitle,movie.srt\r\n"
    L"2,vinput,1\r\n";
const wchar_t kM3uFileName[] = L"playlist.m3u";
const wchar_t kM3uMediaFileName[] = L"song.mp3";
const wchar_t kM3uText[] =
    L"#EXTM3U\r\n"
    L"#EXTINF:1,Song\r\n"
    L"song.mp3\r\n";
const wchar_t kPlsFileName[] = L"playlist.pls";
const wchar_t kPlsMediaFileName[] = L"stream.mp3";
const wchar_t kPlsText[] =
    L"[playlist]\r\n"
    L"File1=stream.mp3\r\n"
    L"Title1=Stream\r\n";
const wchar_t kSubtitleFileName[] = L"subtitle.srt";
const char kSubtitleText[] = "1\r\n00:00:01,000 --> 00:00:02,000\r\nHello\r\n";
const wchar_t kZipFileName[] = L"archive.zip";

std::wstring JoinPath(const std::wstring& dir, const std::wstring& file)
{
  std::wstring path = dir;
  if (!path.empty() && path[path.size() - 1] != L'\\') {
    path += L'\\';
  }
  path += file;
  return path;
}

bool WriteUtf16File(const std::wstring& path, const std::wstring& text)
{
  FILE* file = NULL;
  if (_wfopen_s(&file, path.c_str(), L"wb") != 0 || !file) {
    return false;
  }

  const unsigned char bom[] = {0xff, 0xfe};
  fwrite(bom, 1, sizeof(bom), file);
  fwrite(text.data(), sizeof(wchar_t), text.size(), file);
  fclose(file);
  return true;
}

bool TouchFile(const std::wstring& path)
{
  FILE* file = NULL;
  if (_wfopen_s(&file, path.c_str(), L"wb") != 0 || !file) {
    return false;
  }
  fclose(file);
  return true;
}

bool WriteBytesFile(const std::wstring& path, const char* text)
{
  FILE* file = NULL;
  if (_wfopen_s(&file, path.c_str(), L"wb") != 0 || !file) {
    return false;
  }
  fwrite(text, 1, strlen(text), file);
  fclose(file);
  return true;
}

void AppendU16(std::vector<unsigned char>* bytes, unsigned short value)
{
  bytes->push_back(static_cast<unsigned char>(value & 0xff));
  bytes->push_back(static_cast<unsigned char>((value >> 8) & 0xff));
}

void AppendU32(std::vector<unsigned char>* bytes, unsigned int value)
{
  bytes->push_back(static_cast<unsigned char>(value & 0xff));
  bytes->push_back(static_cast<unsigned char>((value >> 8) & 0xff));
  bytes->push_back(static_cast<unsigned char>((value >> 16) & 0xff));
  bytes->push_back(static_cast<unsigned char>((value >> 24) & 0xff));
}

void AppendText(std::vector<unsigned char>* bytes, const char* text)
{
  bytes->insert(bytes->end(), text, text + strlen(text));
}

void AppendLocalZipHeader(std::vector<unsigned char>* bytes, const char* name)
{
  AppendU32(bytes, 0x04034b50);
  AppendU16(bytes, 20);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU32(bytes, 0);
  AppendU32(bytes, 0);
  AppendU32(bytes, 0);
  AppendU16(bytes, static_cast<unsigned short>(strlen(name)));
  AppendU16(bytes, 0);
  AppendText(bytes, name);
}

void AppendCentralZipHeader(std::vector<unsigned char>* bytes, const char* name, unsigned int localOffset)
{
  AppendU32(bytes, 0x02014b50);
  AppendU16(bytes, 20);
  AppendU16(bytes, 20);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU32(bytes, 0);
  AppendU32(bytes, 0);
  AppendU32(bytes, 0);
  AppendU16(bytes, static_cast<unsigned short>(strlen(name)));
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU16(bytes, 0);
  AppendU32(bytes, 0);
  AppendU32(bytes, localOffset);
  AppendText(bytes, name);
}

bool WriteStoredZipFile(const std::wstring& path)
{
  const char* firstName = "movie.mp4";
  const char* secondName = "subs/movie.srt";
  std::vector<unsigned char> bytes;

  const unsigned int firstLocalOffset = static_cast<unsigned int>(bytes.size());
  AppendLocalZipHeader(&bytes, firstName);
  const unsigned int secondLocalOffset = static_cast<unsigned int>(bytes.size());
  AppendLocalZipHeader(&bytes, secondName);

  const unsigned int centralOffset = static_cast<unsigned int>(bytes.size());
  AppendCentralZipHeader(&bytes, firstName, firstLocalOffset);
  AppendCentralZipHeader(&bytes, secondName, secondLocalOffset);
  const unsigned int centralSize = static_cast<unsigned int>(bytes.size()) - centralOffset;

  AppendU32(&bytes, 0x06054b50);
  AppendU16(&bytes, 0);
  AppendU16(&bytes, 0);
  AppendU16(&bytes, 2);
  AppendU16(&bytes, 2);
  AppendU32(&bytes, centralSize);
  AppendU32(&bytes, centralOffset);
  AppendU16(&bytes, 0);

  FILE* file = NULL;
  if (_wfopen_s(&file, path.c_str(), L"wb") != 0 || !file) {
    return false;
  }
  fwrite(&bytes[0], 1, bytes.size(), file);
  fclose(file);
  return true;
}

int TestCuePlaylistParser()
{
  wchar_t tempPath[MAX_PATH] = {0};
  if (!GetTempPathW(MAX_PATH, tempPath)) {
    _tprintf(_T("GetTempPathW failed\n"));
    return 1;
  }

  std::wstring testDir = JoinPath(tempPath, L"playasa_playlist_parser_cpp_test");
  CreateDirectoryW(testDir.c_str(), NULL);

  const std::wstring cuePath = JoinPath(testDir, kCueFileName);
  const std::wstring mediaPath = JoinPath(testDir, kMediaFileName);
  DeleteFileW(cuePath.c_str());
  DeleteFileW(mediaPath.c_str());

  if (!TouchFile(mediaPath) || !WriteUtf16File(cuePath, kCueText)) {
    _tprintf(_T("Failed to create CUE fixture\n"));
    return 1;
  }

  std::vector<std::wstring> files;
  if (!ParseCuePlaylistWithRust(cuePath, &files)) {
    _tprintf(_T("ParseCuePlaylistWithRust returned no files\n"));
    return 1;
  }
  if (files.size() != 1) {
    _tprintf(_T("Expected 1 playlist item, got %u\n"), (unsigned)files.size());
    return 1;
  }
  if (_wcsicmp(files[0].c_str(), mediaPath.c_str()) != 0) {
    _tprintf(_T("Unexpected media path: %s\n"), files[0].c_str());
    return 1;
  }

  DeleteFileW(cuePath.c_str());
  DeleteFileW(mediaPath.c_str());
  RemoveDirectoryW(testDir.c_str());
  return 0;
}

int TestMpcPlaylistParser()
{
  wchar_t tempPath[MAX_PATH] = {0};
  if (!GetTempPathW(MAX_PATH, tempPath)) {
    _tprintf(_T("GetTempPathW failed\n"));
    return 1;
  }

  std::wstring testDir = JoinPath(tempPath, L"playasa_mpc_playlist_parser_cpp_test");
  CreateDirectoryW(testDir.c_str(), NULL);

  const std::wstring mpcPath = JoinPath(testDir, kMpcFileName);
  const std::wstring mediaPath = JoinPath(testDir, kMpcMediaFileName);
  const std::wstring subtitlePath = JoinPath(testDir, kMpcSubtitleFileName);
  DeleteFileW(mpcPath.c_str());
  DeleteFileW(mediaPath.c_str());
  DeleteFileW(subtitlePath.c_str());

  if (!TouchFile(mediaPath) || !TouchFile(subtitlePath) || !WriteUtf16File(mpcPath, kMpcText)) {
    _tprintf(_T("Failed to create MPC fixture\n"));
    return 1;
  }

  std::vector<RustMpcPlaylistItem> items;
  if (!ParseMpcPlaylistWithRust(mpcPath, &items)) {
    _tprintf(_T("ParseMpcPlaylistWithRust returned no items\n"));
    return 1;
  }
  if (items.size() != 1) {
    _tprintf(_T("Expected 1 MPC item, got %u\n"), (unsigned)items.size());
    return 1;
  }
  if (items[0].label != L"Rust MPC item" || items[0].vinput != 1) {
    _tprintf(_T("Unexpected MPC item metadata\n"));
    return 1;
  }
  if (items[0].filenames.size() != 1 || _wcsicmp(items[0].filenames[0].c_str(), mediaPath.c_str()) != 0) {
    _tprintf(_T("Unexpected MPC media path\n"));
    return 1;
  }
  if (items[0].subtitles.size() != 1 || _wcsicmp(items[0].subtitles[0].c_str(), subtitlePath.c_str()) != 0) {
    _tprintf(_T("Unexpected MPC subtitle path\n"));
    return 1;
  }

  DeleteFileW(mpcPath.c_str());
  DeleteFileW(mediaPath.c_str());
  DeleteFileW(subtitlePath.c_str());
  RemoveDirectoryW(testDir.c_str());
  return 0;
}

int TestM3uPlaylistParser()
{
  wchar_t tempPath[MAX_PATH] = {0};
  if (!GetTempPathW(MAX_PATH, tempPath)) {
    _tprintf(_T("GetTempPathW failed\n"));
    return 1;
  }

  std::wstring testDir = JoinPath(tempPath, L"playasa_m3u_playlist_parser_cpp_test");
  CreateDirectoryW(testDir.c_str(), NULL);

  const std::wstring m3uPath = JoinPath(testDir, kM3uFileName);
  const std::wstring mediaPath = JoinPath(testDir, kM3uMediaFileName);
  DeleteFileW(m3uPath.c_str());
  DeleteFileW(mediaPath.c_str());

  if (!TouchFile(mediaPath) || !WriteUtf16File(m3uPath, kM3uText)) {
    _tprintf(_T("Failed to create M3U fixture\n"));
    return 1;
  }

  std::vector<std::wstring> files;
  if (!ParseM3uPlaylistWithRust(m3uPath, &files)) {
    _tprintf(_T("ParseM3uPlaylistWithRust returned no files\n"));
    return 1;
  }
  if (files.size() != 1 || _wcsicmp(files[0].c_str(), mediaPath.c_str()) != 0) {
    _tprintf(_T("Unexpected M3U media path\n"));
    return 1;
  }

  DeleteFileW(m3uPath.c_str());
  DeleteFileW(mediaPath.c_str());
  RemoveDirectoryW(testDir.c_str());
  return 0;
}

int TestPlsPlaylistParser()
{
  wchar_t tempPath[MAX_PATH] = {0};
  if (!GetTempPathW(MAX_PATH, tempPath)) {
    _tprintf(_T("GetTempPathW failed\n"));
    return 1;
  }

  std::wstring testDir = JoinPath(tempPath, L"playasa_pls_playlist_parser_cpp_test");
  CreateDirectoryW(testDir.c_str(), NULL);

  const std::wstring plsPath = JoinPath(testDir, kPlsFileName);
  const std::wstring mediaPath = JoinPath(testDir, kPlsMediaFileName);
  DeleteFileW(plsPath.c_str());
  DeleteFileW(mediaPath.c_str());

  if (!TouchFile(mediaPath) || !WriteUtf16File(plsPath, kPlsText)) {
    _tprintf(_T("Failed to create PLS fixture\n"));
    return 1;
  }

  std::vector<std::wstring> files;
  if (!ParsePlsPlaylistWithRust(plsPath, &files)) {
    _tprintf(_T("ParsePlsPlaylistWithRust returned no files\n"));
    return 1;
  }
  if (files.size() != 1 || _wcsicmp(files[0].c_str(), mediaPath.c_str()) != 0) {
    _tprintf(_T("Unexpected PLS media path\n"));
    return 1;
  }

  DeleteFileW(plsPath.c_str());
  DeleteFileW(mediaPath.c_str());
  RemoveDirectoryW(testDir.c_str());
  return 0;
}

int TestSubtitleTextProbe()
{
  wchar_t tempPath[MAX_PATH] = {0};
  if (!GetTempPathW(MAX_PATH, tempPath)) {
    _tprintf(_T("GetTempPathW failed\n"));
    return 1;
  }

  std::wstring testDir = JoinPath(tempPath, L"playasa_subtitle_probe_cpp_test");
  CreateDirectoryW(testDir.c_str(), NULL);

  const std::wstring subtitlePath = JoinPath(testDir, kSubtitleFileName);
  if (!WriteBytesFile(subtitlePath, kSubtitleText)) {
    _tprintf(_T("WriteBytesFile failed\n"));
    return 1;
  }

  const PlayasaSubtitleTextProbe probe = playasa_subtitle_probe_text(subtitlePath.c_str());
  if (probe.encoding != PLAYASA_SUBTITLE_ENCODING_UTF8 || probe.format_hint != PLAYASA_SUBTITLE_FORMAT_SRT) {
    _tprintf(_T("Unexpected subtitle probe result\n"));
    return 1;
  }

  DeleteFileW(subtitlePath.c_str());
  RemoveDirectoryW(testDir.c_str());
  return 0;
}

int TestArchiveHelper()
{
  wchar_t tempPath[MAX_PATH] = {0};
  if (!GetTempPathW(MAX_PATH, tempPath)) {
    _tprintf(_T("GetTempPathW failed\n"));
    return 1;
  }

  std::wstring testDir = JoinPath(tempPath, L"playasa_archive_helper_cpp_test");
  CreateDirectoryW(testDir.c_str(), NULL);

  const std::wstring zipPath = JoinPath(testDir, kZipFileName);
  if (!WriteStoredZipFile(zipPath)) {
    _tprintf(_T("WriteStoredZipFile failed\n"));
    return 1;
  }

  PlayasaArchiveEntryList list = playasa_archive_list_zip(zipPath.c_str());
  if (list.len != 2 || list.items == NULL) {
    _tprintf(_T("Unexpected ZIP entry count\n"));
    playasa_archive_free_entry_list(list);
    return 1;
  }

  std::wstring first(list.items[0].ptr, list.items[0].len);
  std::wstring second(list.items[1].ptr, list.items[1].len);
  const bool ok = first == L"movie.mp4" && second == L"subs/movie.srt";
  playasa_archive_free_entry_list(list);

  DeleteFileW(zipPath.c_str());
  RemoveDirectoryW(testDir.c_str());
  if (!ok) {
    _tprintf(_T("Unexpected ZIP entry names\n"));
    return 1;
  }
  return 0;
}

}  // namespace

int _tmain(int argc, _TCHAR* argv[])
{
  (void)argc;
  (void)argv;
  int result = TestCuePlaylistParser();
  if (result != 0) {
    return result;
  }
  result = TestMpcPlaylistParser();
  if (result != 0) {
    return result;
  }
  result = TestM3uPlaylistParser();
  if (result != 0) {
    return result;
  }
  result = TestPlsPlaylistParser();
  if (result != 0) {
    return result;
  }
  result = TestSubtitleTextProbe();
  if (result != 0) {
    return result;
  }
  return TestArchiveHelper();
}

