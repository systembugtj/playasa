#include "../stdafx.h"

#include "RealVideoPresentationTiming.h"

bool PlayasaApplyRealVideoInputTiming(
	DWORD& timestamp,
	DWORD& last_shown_timestamp,
	bool& drop_frames,
	int& rv_leap_frames,
	int& rv_time_for_each_leap,
	REFERENCE_TIME sample_rt_start,
	REFERENCE_TIME rt_avr_time_per_frame,
	DWORD& in_timestamp_out)
{
	if (rv_time_for_each_leap == 0) {
		rv_time_for_each_leap = static_cast<int>(rt_avr_time_per_frame / 10000);
	}

	DWORD in_timestamp = static_cast<DWORD>(sample_rt_start / 10000);
	if (timestamp + 1 == in_timestamp) {
		if (drop_frames) {
			return true;
		}

		rv_leap_frames++;
		timestamp = in_timestamp;
		in_timestamp = last_shown_timestamp + static_cast<DWORD>(rv_time_for_each_leap);
	} else {
		if (rv_leap_frames) {
			rv_time_for_each_leap = static_cast<int>(in_timestamp - timestamp + rv_leap_frames) / (rv_leap_frames + 1);
		}

		timestamp = in_timestamp;
		rv_leap_frames = 0;
	}

	last_shown_timestamp = in_timestamp;
	in_timestamp_out = in_timestamp;
	return false;
}

REFERENCE_TIME PlayasaApplyRealVideoOutputRtStart(
	REFERENCE_TIME& rt_rv_start,
	DWORD in_timestamp,
	REFERENCE_TIME t_start,
	REFERENCE_TIME rt_avr_time_per_frame)
{
	REFERENCE_TIME rt_start = 10000i64 * static_cast<REFERENCE_TIME>(in_timestamp) - t_start;
	rt_rv_start += rt_avr_time_per_frame;
	if (rt_start > rt_rv_start) {
		rt_start = rt_rv_start + (rt_start - rt_rv_start) / 8;
	} else {
		rt_start = rt_rv_start - (rt_rv_start - rt_start) / 10;
	}

	rt_rv_start = rt_start;
	return rt_start;
}
