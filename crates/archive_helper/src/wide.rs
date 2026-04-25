pub(crate) fn encode_wide(value: &str) -> Box<[u16]> {
    value.encode_utf16().collect::<Vec<_>>().into_boxed_slice()
}
