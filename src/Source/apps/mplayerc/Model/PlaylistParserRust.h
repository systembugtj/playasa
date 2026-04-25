#pragma once

#include <string>
#include <vector>

struct RustMpcPlaylistItem {
	int type;
	std::wstring label;
	std::vector<std::wstring> filenames;
	std::vector<std::wstring> subtitles;
	long vinput;
	long vchannel;
	long ainput;
	long country;
};

bool ParseCuePlaylistWithRust(const std::wstring& path, std::vector<std::wstring>* files);
bool ParseMpcPlaylistWithRust(const std::wstring& path, std::vector<RustMpcPlaylistItem>* items);
