#pragma once
#include "logging.h"
/*
 * This file include:
 *  1. class ThreadHelperImpl
 *
 * Example:
 *
 * class ThreadSample : public ThreadHelperImpl<ThreadSample>
 * {
 *   // do something
 *   void _Thread()
 *   {
 *
 *   }
 * };
 *
 * ThreadSample mythread;
 * mythread._Stop();
 * mythread._Start();
 *
 */

template<class T>
class ThreadHelperImpl
{
public:
	ThreadHelperImpl() :m_thread(NULL),
		m_stopevent(::CreateEvent(NULL, TRUE, FALSE, NULL)) {}
	~ThreadHelperImpl() { _Stop(); }

	// Create a new thread
	void _Start(int nPriority = THREAD_PRIORITY_IDLE)
	{
		if (_Is_alive())
			return;

		m_thread = (HANDLE)::_beginthread(Logic, 0, (T*)this);
		m_priority = nPriority;
	}

	// Stop the thread
	void _Stop(int wait_msec = 300, int times = 6)
	{
		if (!_Is_alive())
			return;

		::SetEvent(m_stopevent);
		if (wait_msec && times)
			for (int i = 0; i < times; i++)
				if (_Is_alive())
					::WaitForSingleObject(m_thread, wait_msec);

		if (_Is_alive())
			TerminateThread(m_thread, 0); // very bad bad bad

		_ResetThread();
	}

	// Use thread do something
	void _Thread() {}

	// Check thread event state.
	// The _Stop Method affecting this state.
	// true if the thread stop,otherwise false.
	bool _Exit_state(int wait_msec)
	{
		return (::WaitForSingleObject(m_stopevent, wait_msec) == WAIT_OBJECT_0)
			? true : false;
	}

	// thread alive;
	// true if thread is alive, otherwise false.
	bool _Is_alive()
	{
		unsigned long thread_exitcode;
		return (m_thread && m_thread != INVALID_HANDLE_VALUE &&
			GetExitCodeThread(m_thread, &thread_exitcode) &&
			thread_exitcode == STILL_ACTIVE) ? true : false;
	}

	DWORD _GetThreadId()
	{
		return ::GetCurrentThreadId();
	}

	void _ResetThread()
	{
		m_thread = NULL;
		::ResetEvent(m_stopevent);
	}
	int    m_priority;
private:
	static void Logic(void* t)
	{
		HANDLE thread_cur = GetCurrentThread();
		if (static_cast<T*>(t)->m_priority == THREAD_PRIORITY_IDLE)
			SetThreadPriority(thread_cur, THREAD_MODE_BACKGROUND_BEGIN);

		SetThreadPriority(thread_cur, static_cast<T*>(t)->m_priority);

		static_cast<T*>(t)->_Thread();
		static_cast<T*>(t)->_ResetThread();

	}

private:
	HANDLE m_thread;
	HANDLE m_stopevent;

};