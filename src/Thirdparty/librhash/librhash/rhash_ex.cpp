#include "rhash_ex.h"
#include <sstream>
#include <string>
#include <vector>

namespace {

// 不依赖 Boost：从完整路径取文件名（与历史行为一致）
std::string path_filename_string(const std::string& file)
{
  const size_t pos = file.find_last_of("/\\");
  if (pos == std::string::npos)
  {
    return file;
  }
  return file.substr(pos + 1);
}

} // namespace

// hash_id 可为 RHASH_ED2K，或 RHASH_ED2K|RHASH_SHA1|RHASH_BTIH 等按位组合（由 rhash_init 解析）
void RHash::create_link(unsigned hash_id, const std::string &file, std::vector<std::string> &result)
{
  rhash ctx = rhash_init(hash_id);
  if (ctx == 0) return;

  FILE *fd = fopen(file.c_str(), "rb");
  if (fd == 0)
  {
    rhash_free(ctx);
    return;
  }

  fseek(fd, 0, SEEK_END);
  long size = ftell(fd);
  rewind(fd);
  std::stringstream ssSize;
  ssSize << size;

  rhash_file_update(ctx, fd);
  fclose(fd);
  fd = 0;

  bool b = true;
  std::string value;
  std::string to_save;

  b = _get_link_internal(RHASH_ED2K, ctx, value);
  if (b)
  {
    to_save = "";
    to_save += "ed2k://|file|" + path_filename_string(file);
    to_save += "|" + ssSize.str();
    to_save += "|" + value + "|/";
    result.push_back(to_save);
  }

  b = _get_link_internal(RHASH_SHA1, ctx, value);
  if (b)
  {
    to_save = "";
    to_save += "magnet:?xt=urn:sha1:" + value;
    result.push_back(to_save);
  }

  b = _get_link_internal(RHASH_BTIH, ctx, value);
  if (b)
  {
    to_save = "";
    to_save += "magnet:?xt=urn:btih:" + value;
    result.push_back(to_save);
  }

  rhash_free(ctx);
  ctx = 0;
}

bool RHash::_get_link_internal(unsigned hash_id, rhash ctx, std::string &result)
{
  const unsigned long long mask = ctx->hash_mask;
  if ((mask & hash_id) == 0)
  {
    return false;
  }

  const int hexLen = rhash_get_hash_length(hash_id);
  if (hexLen <= 0)
  {
    return false;
  }

  std::vector<char> buf(static_cast<size_t>(hexLen) + 8u, '\0');
  const size_t n = rhash_print(buf.data(), ctx, hash_id, RHPR_HEX | RHPR_UPPERCASE);
  if (n == 0)
  {
    return false;
  }

  size_t len = n;
  while (len > 0 && buf[len - 1] == '\0')
  {
    --len;
  }
  result.assign(buf.data(), len);
  return true;
}
