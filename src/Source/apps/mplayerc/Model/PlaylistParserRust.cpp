#include "stdafx.h"
#include "PlaylistParserRust.h"

#include <playlist_parser_rust.h>
#include <map>
#include <set>

namespace {

std::wstring ToString(const PlayasaMpcPlaylistField& field)
{
	return field.ptr && field.len > 0 ? std::wstring(field.ptr, field.len) : std::wstring();
}

void EnsureTwoFilenames(RustMpcPlaylistItem* item)
{
	while (item->filenames.size() < 2) {
		item->filenames.push_back(std::wstring());
	}
}

}  // namespace

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

bool ParseMpcPlaylistWithRust(const std::wstring& path, std::vector<RustMpcPlaylistItem>* items)
{
	if (!items) {
		return false;
	}

	PlayasaMpcPlaylistFieldList list = playasa_playlist_parse_mpc(path.c_str());
	std::map<int, RustMpcPlaylistItem> byIndex;
	std::set<int> typedIndexes;

	for (size_t i = 0; i < list.len; ++i) {
		const PlayasaMpcPlaylistField& field = list.items[i];
		RustMpcPlaylistItem& item = byIndex[field.index];

		switch (field.key) {
		case PLAYASA_MPC_KEY_TYPE:
			item.type = static_cast<int>(field.number);
			typedIndexes.insert(field.index);
			break;
		case PLAYASA_MPC_KEY_LABEL:
			item.label = ToString(field);
			break;
		case PLAYASA_MPC_KEY_FILENAME:
			item.filenames.push_back(ToString(field));
			break;
		case PLAYASA_MPC_KEY_SUBTITLE:
			item.subtitles.push_back(ToString(field));
			break;
		case PLAYASA_MPC_KEY_VIDEO:
			EnsureTwoFilenames(&item);
			item.filenames[0] = ToString(field);
			break;
		case PLAYASA_MPC_KEY_AUDIO:
			EnsureTwoFilenames(&item);
			item.filenames[1] = ToString(field);
			break;
		case PLAYASA_MPC_KEY_VINPUT:
			item.vinput = static_cast<long>(field.number);
			break;
		case PLAYASA_MPC_KEY_VCHANNEL:
			item.vchannel = static_cast<long>(field.number);
			break;
		case PLAYASA_MPC_KEY_AINPUT:
			item.ainput = static_cast<long>(field.number);
			break;
		case PLAYASA_MPC_KEY_COUNTRY:
			item.country = static_cast<long>(field.number);
			break;
		default:
			break;
		}
	}

	for (std::set<int>::const_iterator it = typedIndexes.begin(); it != typedIndexes.end(); ++it) {
		items->push_back(byIndex[*it]);
	}

	playasa_playlist_free_mpc_field_list(list);
	return !items->empty();
}
