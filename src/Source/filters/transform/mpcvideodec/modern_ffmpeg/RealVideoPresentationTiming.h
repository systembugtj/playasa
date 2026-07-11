#pragma once

// RFC-0032: shared RealVideo leap/timestamp smoothing for legacy and modern decode paths.

static const DWORD kPlayasaRealVideoNoInputTimestamp = static_cast<DWORD>(~0u);

// Returns true when the packet should be dropped without decoding (legacy drop-frames mode).
bool PlayasaApplyRealVideoInputTiming(
	DWORD& timestamp,
	DWORD& last_shown_timestamp,
	bool& drop_frames,
	int& rv_leap_frames,
	int& rv_time_for_each_leap,
	REFERENCE_TIME sample_rt_start,
	REFERENCE_TIME rt_avr_time_per_frame,
	DWORD& in_timestamp_out);

REFERENCE_TIME PlayasaApplyRealVideoOutputRtStart(
	REFERENCE_TIME& rt_rv_start,
	DWORD in_timestamp,
	REFERENCE_TIME t_start,
	REFERENCE_TIME rt_avr_time_per_frame);
