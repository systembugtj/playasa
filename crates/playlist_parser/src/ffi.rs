use crate::cue::parse_cue_text;
use crate::m3u::parse_m3u_text;
use crate::mpc::{parse_mpc_text, OwnedMpcField};
use crate::paths::encode_path;
use crate::pls::parse_pls_text;
use crate::text::{read_text_lossy, wide_path_from_ptr};

#[repr(C)]
pub struct PlayasaPlaylistPath {
    ptr: *mut u16,
    len: usize,
}

#[repr(C)]
pub struct PlayasaPlaylistPathList {
    items: *mut PlayasaPlaylistPath,
    len: usize,
}

#[repr(C)]
pub struct PlayasaMpcPlaylistField {
    index: i32,
    key: i32,
    ptr: *mut u16,
    len: usize,
    number: i64,
}

#[repr(C)]
pub struct PlayasaMpcPlaylistFieldList {
    items: *mut PlayasaMpcPlaylistField,
    len: usize,
}

#[no_mangle]
pub extern "C" fn playasa_playlist_parse_cue(path: *const u16) -> PlayasaPlaylistPathList {
    let result = std::panic::catch_unwind(|| unsafe { parse_cue_ffi(path) });
    result.unwrap_or_else(|_| empty_path_list())
}

#[no_mangle]
pub extern "C" fn playasa_playlist_parse_m3u(path: *const u16) -> PlayasaPlaylistPathList {
    let result = std::panic::catch_unwind(|| unsafe { parse_m3u_ffi(path) });
    result.unwrap_or_else(|_| empty_path_list())
}

#[no_mangle]
pub extern "C" fn playasa_playlist_parse_pls(path: *const u16) -> PlayasaPlaylistPathList {
    let result = std::panic::catch_unwind(|| unsafe { parse_pls_ffi(path) });
    result.unwrap_or_else(|_| empty_path_list())
}

#[no_mangle]
pub extern "C" fn playasa_playlist_parse_mpc(path: *const u16) -> PlayasaMpcPlaylistFieldList {
    let result = std::panic::catch_unwind(|| unsafe { parse_mpc_ffi(path) });
    result.unwrap_or_else(|_| empty_mpc_field_list())
}

#[no_mangle]
pub extern "C" fn playasa_playlist_free_path_list(list: PlayasaPlaylistPathList) {
    unsafe {
        free_path_list(list);
    }
}

#[no_mangle]
pub extern "C" fn playasa_playlist_free_mpc_field_list(list: PlayasaMpcPlaylistFieldList) {
    unsafe {
        free_mpc_field_list(list);
    }
}

unsafe fn parse_cue_ffi(path: *const u16) -> PlayasaPlaylistPathList {
    let Ok(path) = wide_path_from_ptr(path) else {
        return empty_path_list();
    };
    let Ok(text) = read_text_lossy(&path) else {
        return empty_path_list();
    };

    to_path_list(parse_cue_text(&text, &path))
}

unsafe fn parse_m3u_ffi(path: *const u16) -> PlayasaPlaylistPathList {
    let Ok(path) = wide_path_from_ptr(path) else {
        return empty_path_list();
    };
    let Ok(text) = read_text_lossy(&path) else {
        return empty_path_list();
    };

    to_path_list(parse_m3u_text(&text, &path))
}

unsafe fn parse_pls_ffi(path: *const u16) -> PlayasaPlaylistPathList {
    let Ok(path) = wide_path_from_ptr(path) else {
        return empty_path_list();
    };
    let Ok(text) = read_text_lossy(&path) else {
        return empty_path_list();
    };

    to_path_list(parse_pls_text(&text, &path))
}

unsafe fn parse_mpc_ffi(path: *const u16) -> PlayasaMpcPlaylistFieldList {
    let Ok(path) = wide_path_from_ptr(path) else {
        return empty_mpc_field_list();
    };
    let Ok(text) = read_text_lossy(&path) else {
        return empty_mpc_field_list();
    };

    to_mpc_field_list(parse_mpc_text(&text, &path))
}

fn to_path_list(paths: Vec<std::path::PathBuf>) -> PlayasaPlaylistPathList {
    if paths.is_empty() {
        return empty_path_list();
    }

    let mut items = paths
        .into_iter()
        .map(|path| {
            let mut wide = encode_path(&path);
            let len = wide.len();
            let ptr = wide.as_mut_ptr();
            std::mem::forget(wide);
            PlayasaPlaylistPath { ptr, len }
        })
        .collect::<Vec<_>>();

    let len = items.len();
    let ptr = items.as_mut_ptr();
    std::mem::forget(items);
    PlayasaPlaylistPathList { items: ptr, len }
}

fn to_mpc_field_list(fields: Vec<OwnedMpcField>) -> PlayasaMpcPlaylistFieldList {
    if fields.is_empty() {
        return empty_mpc_field_list();
    }

    let mut items = fields
        .into_iter()
        .map(|field| {
            let (ptr, len) = match field.value {
                Some(mut value) => {
                    let len = value.len();
                    let ptr = value.as_mut_ptr();
                    std::mem::forget(value);
                    (ptr, len)
                }
                None => (std::ptr::null_mut(), 0),
            };
            PlayasaMpcPlaylistField {
                index: field.index,
                key: field.key,
                ptr,
                len,
                number: field.number,
            }
        })
        .collect::<Vec<_>>();

    let len = items.len();
    let ptr = items.as_mut_ptr();
    std::mem::forget(items);
    PlayasaMpcPlaylistFieldList { items: ptr, len }
}

const fn empty_path_list() -> PlayasaPlaylistPathList {
    PlayasaPlaylistPathList {
        items: std::ptr::null_mut(),
        len: 0,
    }
}

const fn empty_mpc_field_list() -> PlayasaMpcPlaylistFieldList {
    PlayasaMpcPlaylistFieldList {
        items: std::ptr::null_mut(),
        len: 0,
    }
}

unsafe fn free_path_list(list: PlayasaPlaylistPathList) {
    if list.items.is_null() || list.len == 0 {
        return;
    }

    let items = Vec::from_raw_parts(list.items, list.len, list.len);
    for item in items {
        if !item.ptr.is_null() && item.len > 0 {
            drop(Vec::from_raw_parts(item.ptr, item.len, item.len));
        }
    }
}

unsafe fn free_mpc_field_list(list: PlayasaMpcPlaylistFieldList) {
    if list.items.is_null() || list.len == 0 {
        return;
    }

    let items = Vec::from_raw_parts(list.items, list.len, list.len);
    for item in items {
        if !item.ptr.is_null() && item.len > 0 {
            drop(Vec::from_raw_parts(item.ptr, item.len, item.len));
        }
    }
}
