#pragma once

#include "monitor.h"
#include "constant.h"
#include <map>
#include <memory>
#include <tuple>

namespace MT
{
  class factory
  {
  public:
    typedef std::shared_ptr<monitor_base> monitor_ptr;
    typedef std::tuple<monitor_type_enum, std::wstring> key_type;
    
  public:
    static monitor_ptr get_monitor(monitor_type_enum type, const std::wstring& counter_object = L"_Total");

  private:
    static std::map<key_type, monitor_ptr > m_stored;
  };
}
