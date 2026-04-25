// PlaylistParser_UnitTest.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include "../../Source/apps/mplayerc/Model/PlaylistParserRust.h"

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

}  // namespace

int _tmain(int argc, _TCHAR* argv[])
{
  (void)argc;
  (void)argv;
  int result = TestCuePlaylistParser();
  if (result != 0) {
    return result;
  }
  return TestMpcPlaylistParser();
}

