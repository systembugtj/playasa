#pragma once

// MSVC 14.50+ still ships std::experimental::filesystem but emits #error unless silenced.
#ifndef _SILENCE_EXPERIMENTAL_FILESYSTEM_DEPRECATION_WARNING
#define _SILENCE_EXPERIMENTAL_FILESYSTEM_DEPRECATION_WARNING
#endif

#include <cstdint>
#include <experimental/filesystem>

namespace mpc_fs = std::experimental::filesystem;
