#pragma once

#include <string>
#include <vector>

bool ParseCuePlaylistWithRust(const std::wstring& path, std::vector<std::wstring>* files);
