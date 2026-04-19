#pragma once

#include <Pdh.h>
#include <PdhMsg.h>
#include <atomic>
#include <memory>
#include <thread>
#include "notify.h"

namespace MT
{
  // base is the base class for all the monitor classes
  // base has the ability to notify the listener if a status is changed
  class monitor_base
  {
  public:
    // constructor/destructor
    monitor_base();
    virtual ~monitor_base();

    // get the current value
    double get_cur_value() const { return m_cur_value; }

    // get notifier to add and remove listeners
    std::shared_ptr<notifier> get_notifier() { return m_notifier; }

    // query monitor status
    virtual bool is_running() const { return m_is_running; }

    // start and stop monitoring
    virtual void start_monitoring();
    virtual void stop_monitoring();

    // set query interval, default is only 100 milliseconds
    virtual void set_interval(int milliseconds) { m_interval = milliseconds; }

    // pdh counter
    virtual std::wstring get_counter() = 0;

  protected:
    void clean_pdh();    // clean pdh
    void stop_thread();  // stop thread

  private:
    void thread_worker();   // the working thread

  protected:
    // notifier
    std::shared_ptr<notifier> m_notifier;

    // control the thread (cooperative stop via m_stop_requested)
    std::unique_ptr<std::thread> m_thread;
    std::atomic<bool> m_stop_requested;
    bool m_is_running;
    int m_interval;
    HQUERY m_hQuery;

    // result
    double m_cur_value;
  };
}

namespace MT
{
  // monitor the cpu status
  class cpu : public monitor_base
  {
  public:
    cpu(const std::wstring &which_cpu, const std::wstring &counter_string);
    ~cpu() { stop_thread(); }
    // pdh counter
    virtual std::wstring get_counter();

  private:
    std::wstring m_which_cpu;
    std::wstring m_counter_string;
  };
}

namespace MT
{
  // monitor the disk status
  class disk : public monitor_base
  {
  public:
    disk(const std::wstring &which_disk, const std::wstring &counter_string);
    ~disk() { stop_thread(); }
    // pdh counter
    virtual std::wstring get_counter();

  private:
    std::wstring m_which_disk;
    std::wstring m_counter_string;
  };
}
