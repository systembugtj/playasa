#include "stdafx.h"

#include <cstdio>
#include <map>
#include <string>

#include "../../../Thirdparty/unrar/unrar.hpp"

namespace {

struct ChunkState {
  FILE* file;
  std::wstring path;
};

typedef std::map<HANDLE, ChunkState*> ChunkStateMap;

ChunkStateMap& GetChunkStates()
{
  static ChunkStateMap states;
  return states;
}

int CALLBACK CaptureUnrarData(UINT msg, LPARAM user_data, LPARAM p1, LPARAM p2)
{
  if (msg != UCM_PROCESSDATA)
  {
    return 1;
  }

  ChunkState* state = reinterpret_cast<ChunkState*>(user_data);
  if (!state || !state->file || !p1 || p2 < 0)
  {
    return -1;
  }

  const size_t written = fwrite(reinterpret_cast<const void*>(p1), 1, static_cast<size_t>(p2), state->file);
  return written == static_cast<size_t>(p2) ? 1 : -1;
}

void DestroyChunkState(ChunkState* state)
{
  if (!state)
  {
    return;
  }

  if (state->file)
  {
    fclose(state->file);
    state->file = NULL;
  }

  if (!state->path.empty())
  {
    DeleteFileW(state->path.c_str());
  }

  delete state;
}

}  // namespace

extern "C" int PASCAL RARExtractChunkInit(HANDLE hArcData, char* file)
{
  UNREFERENCED_PARAMETER(file);

  RARExtractChunkClose(hArcData);

  wchar_t temp_dir[MAX_PATH] = {0};
  if (GetTempPathW(MAX_PATH, temp_dir) == 0)
  {
    return ERAR_ECREATE;
  }

  wchar_t temp_file[MAX_PATH] = {0};
  if (GetTempFileNameW(temp_dir, L"rar", 0, temp_file) == 0)
  {
    return ERAR_ECREATE;
  }

  ChunkState* state = new ChunkState();
  state->file = NULL;
  state->path = temp_file;

  if (_wfopen_s(&state->file, state->path.c_str(), L"w+b") != 0 || !state->file)
  {
    DestroyChunkState(state);
    return ERAR_ECREATE;
  }

  RARSetCallback(hArcData, CaptureUnrarData, reinterpret_cast<LPARAM>(state));
  const int result = RARProcessFile(hArcData, RAR_TEST, NULL, NULL);
  RARSetCallback(hArcData, NULL, 0);
  if (result != 0)
  {
    DestroyChunkState(state);
    return result;
  }

  if (_fseeki64(state->file, 0, SEEK_SET) != 0)
  {
    DestroyChunkState(state);
    return ERAR_EREAD;
  }

  GetChunkStates()[hArcData] = state;
  return 0;
}

extern "C" void PASCAL RARExtractChunkClose(HANDLE hArcData)
{
  ChunkStateMap& states = GetChunkStates();
  ChunkStateMap::iterator it = states.find(hArcData);
  if (it == states.end())
  {
    return;
  }

  DestroyChunkState(it->second);
  states.erase(it);
}

extern "C" int PASCAL RARExtractChunk(HANDLE hArcData, char* buf, size_t len)
{
  ChunkStateMap& states = GetChunkStates();
  ChunkStateMap::iterator it = states.find(hArcData);
  if (it == states.end() || !buf)
  {
    return -1;
  }

  return static_cast<int>(fread(buf, 1, len, it->second->file));
}

extern "C" int PASCAL RARExtractChunkSeek(HANDLE hArcData, unsigned long long offset, int flag)
{
  ChunkStateMap& states = GetChunkStates();
  ChunkStateMap::iterator it = states.find(hArcData);
  if (it == states.end())
  {
    return -1;
  }

  return _fseeki64(it->second->file, static_cast<__int64>(offset), flag);
}
