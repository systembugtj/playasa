#include "stdafx.h"
#include "PlaylistParserRust.h"

#include <playlist_parser_rust.h>

bool ParseCuePlaylistWithRust(const std::wstring& path, std::vector<std::wstring>* files)
{
	if (!files) {
		return false;
	}

	PlayasaPlaylistPathList list = playasa_playlist_parse_cue(path.c_str());
	for (size_t i = 0; i < list.len; ++i) {
		const PlayasaPlaylistPath& item = list.items[i];
		if (item.ptr && item.len > 0) {
			files->push_back(std::wstring(item.ptr, item.len));
		}
	}
	playasa_playlist_free_path_list(list);

	return !files->empty();
}
