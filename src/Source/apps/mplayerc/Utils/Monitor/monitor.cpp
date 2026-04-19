#include "stdafx.h"
#include "monitor.h"
#include <chrono>
#pragma comment(lib, "pdh.lib")

////////////////////////////////////////////////////////////////////////////////
// monitor_base
MT::monitor_base::monitor_base()
: m_notifier(std::make_shared<notifier>())
, m_stop_requested(false)
, m_is_running(false)
, m_interval(100)
, m_hQuery(0)
, m_cur_value(0)
{

}

MT::monitor_base::~monitor_base()
{
  stop_thread();
  clean_pdh();
}

void MT::monitor_base::start_monitoring()
{
  if (!m_thread)
  {
    m_stop_requested = false;
    m_thread.reset(new std::thread(&MT::monitor_base::thread_worker, this));
  }

  m_is_running = true;
}

void MT::monitor_base::stop_monitoring()
{
  m_is_running = false;
}

void MT::monitor_base::clean_pdh()
{
  if (m_hQuery)
    PdhCloseQuery(m_hQuery);
  m_hQuery = 0;
}

void MT::monitor_base::stop_thread()
{
  stop_monitoring();

  m_stop_requested = true;
  if (m_thread)
  {
    m_thread->join();
    m_thread.reset();
  }
}

void MT::monitor_base::thread_worker()
{
  // prepare
  HCOUNTER hCounter = 0;
  PDH_STATUS status = ERROR_SUCCESS;
  DWORD dwFormat = PDH_FMT_DOUBLE; 
  PDH_FMT_COUNTERVALUE ItemBuffer = {0};
  status = PdhOpenQuery(0, 0, &m_hQuery);
  if (!m_hQuery)
  {
    clean_pdh();
    m_is_running = false;
    return;
  }

  // add counter
  status = PdhAddCounter(m_hQuery, get_counter().c_str(), 0, &hCounter);
  if (status != ERROR_SUCCESS)
  {
    clean_pdh();
    m_is_running = false;
    return;
  }

  while (!m_stop_requested)
  {
    // check if running
    if (!m_is_running)
    {
      std::this_thread::sleep_for(std::chrono::milliseconds(300));
      continue;
    }

    // do the job
    status = PdhCollectQueryData(m_hQuery);
    if (ERROR_SUCCESS == status)
    {
      // Format the performance data record.
      status = PdhGetFormattedCounterValue(hCounter, dwFormat, 0, &ItemBuffer);
      m_cur_value = ItemBuffer.doubleValue;

      // emit the signal
      m_notifier->notify();
    }

    // sleep for next notify
    std::this_thread::sleep_for(std::chrono::milliseconds(m_interval));
  }

  clean_pdh();
}

////////////////////////////////////////////////////////////////////////////////
// cpu
MT::cpu::cpu(const std::wstring &which_cpu, const std::wstring &counter_string)
: m_which_cpu(which_cpu)
, m_counter_string(counter_string)
{

}

std::wstring MT::cpu::get_counter()
{
  return L"\\Processor(" + m_which_cpu + L")\\" + m_counter_string;
}

////////////////////////////////////////////////////////////////////////////////
// disk
MT::disk::disk(const std::wstring &which_disk, const std::wstring &counter_string)
: m_which_disk(which_disk)
, m_counter_string(counter_string)
{

}

std::wstring MT::disk::get_counter()
{
  return L"\\PhysicalDisk(" + m_which_disk + L")\\" + m_counter_string;
}
