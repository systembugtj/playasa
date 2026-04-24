#include "stdafx.h"
#include "rsc_format.h"
#include "../Utils/zlib_utils.h"
#include "../Utils/strings.h"
#include "../Utils/base64_utils.h"

#include <fstream>
#include <string>
#include <yaml-cpp/yaml.h>

namespace
{

const char kStringNodeName[] = "string";
const char kBinaryNodeName[] = "bin";

bool CopyStringMap(const YAML::Node& node, std::map<std::wstring, std::wstring>& output)
{
  if (!node || !node.IsMap())
    return false;

  for (YAML::const_iterator it = node.begin(); it != node.end(); ++it)
  {
    const std::string key = it->first.as<std::string>();
    const std::string value = it->second.as<std::string>();
    output[string_util::Utf8StringToWString(key)] = string_util::Utf8StringToWString(value);
  }

  return true;
}

bool CopyBinaryMap(const YAML::Node& node, std::map<std::wstring, std::vector<unsigned char> >& output)
{
  if (!node || !node.IsMap())
    return false;

  for (YAML::const_iterator it = node.begin(); it != node.end(); ++it)
  {
    const std::string key = it->first.as<std::string>();
    const std::string value = it->second.as<std::string>();
    output[string_util::Utf8StringToWString(key)] = base64_utils::Decode(value);
  }

  return true;
}

} // namespace

namespace rsc_format
{

bool Parse(const wchar_t* filename, std::map<std::wstring, std::wstring>& str_output,
           std::map<std::wstring, std::vector<unsigned char> >& buf_output)
{
  std::ifstream fs(filename, std::ios::binary);

  str_output.clear();
  buf_output.clear();

  if (!fs.is_open())
    return false;

  fs.seekg(0, std::ios::end);
  const std::ifstream::pos_type file_size = fs.tellg();
  fs.seekg(0, std::ios::beg);

  if (file_size <= 0)
    return false;

  const size_t buffer_size = static_cast<size_t>(file_size);
  std::vector<unsigned char> buffer(buffer_size);
  fs.read(reinterpret_cast<char*>(&buffer[0]), static_cast<std::streamsize>(buffer_size));
  fs.close();

  std::vector<unsigned char> yaml_utf8s = zlib_utils::Uncompress(buffer);
  if (yaml_utf8s.empty())
    return false;

  yaml_utf8s.push_back(0);

  try
  {
    const YAML::Node doc = YAML::Load(reinterpret_cast<const char*>(&yaml_utf8s[0]));
    if (!doc || !doc.IsMap())
      return false;

    if (!CopyStringMap(doc[kStringNodeName], str_output))
      return false;

    if (!CopyBinaryMap(doc[kBinaryNodeName], buf_output))
      return false;
  }
  catch (YAML::Exception& e)
  {
    UNREFERENCED_LOCAL_VARIABLE(e);
    return false;
  }

  return true;
}

} // namespace rsc_format