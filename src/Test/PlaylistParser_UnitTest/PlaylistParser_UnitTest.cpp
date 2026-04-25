// PlaylistParser_UnitTest.cpp : Defines the entry point for the console application.
//

#include "stdafx.h"
#include "../../Source/apps/mplayerc/Model/PlaylistParserRust.h"

namespace {

const wchar_t kCueFileName[] = L"album.cue";
const wchar_t kMediaFileName[] = L"Track 01.flac";
const wchar_t kCueText[] = L"FILE \"Track 01.flac\" WAVE\r\n";

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

}  // namespace

int _tmain(int argc, _TCHAR* argv[])
{
  (void)argc;
  (void)argv;
  return TestCuePlaylistParser();
}

