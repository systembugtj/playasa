const MD5_HEX_LEN: usize = 32;

pub(crate) fn md5_hex(input: &[u8]) -> String {
    let mut context = Md5Context::new();
    context.update(input);
    to_hex(&context.finalize())
}

pub(crate) fn digest_hex(bytes: &[u8; 16]) -> String {
    to_hex(bytes)
}

pub(crate) fn expected_hex_len() -> usize {
    MD5_HEX_LEN
}

fn to_hex(bytes: &[u8; 16]) -> String {
    const HEX: &[u8; 16] = b"0123456789abcdef";
    let mut out = String::with_capacity(MD5_HEX_LEN);

    for byte in bytes {
        out.push(HEX[(byte >> 4) as usize] as char);
        out.push(HEX[(byte & 0x0f) as usize] as char);
    }

    out
}

pub(crate) struct Md5Context {
    state: [u32; 4],
    buffer: [u8; 64],
    buffer_len: usize,
    total_len: u64,
}

impl Md5Context {
    pub(crate) fn new() -> Self {
        Self {
            state: [0x6745_2301, 0xefcd_ab89, 0x98ba_dcfe, 0x1032_5476],
            buffer: [0; 64],
            buffer_len: 0,
            total_len: 0,
        }
    }

    pub(crate) fn update(&mut self, input: &[u8]) {
        self.total_len += input.len() as u64;
        let mut cursor = 0usize;

        if self.buffer_len > 0 {
            let bytes_to_copy = (64 - self.buffer_len).min(input.len());
            self.buffer[self.buffer_len..self.buffer_len + bytes_to_copy]
                .copy_from_slice(&input[..bytes_to_copy]);
            self.buffer_len += bytes_to_copy;
            cursor += bytes_to_copy;

            if self.buffer_len == 64 {
                transform(&mut self.state, &self.buffer);
                self.buffer_len = 0;
            }
        }

        while cursor + 64 <= input.len() {
            let block: &[u8; 64] = input[cursor..cursor + 64]
                .try_into()
                .expect("64-byte block");
            transform(&mut self.state, block);
            cursor += 64;
        }

        if cursor < input.len() {
            let remaining = &input[cursor..];
            self.buffer[..remaining.len()].copy_from_slice(remaining);
            self.buffer_len = remaining.len();
        }
    }

    pub(crate) fn finalize(mut self) -> [u8; 16] {
        let bit_len = self.total_len.wrapping_mul(8);
        let mut padding = [0u8; 64];
        padding[0] = 0x80;

        let pad_len = if self.buffer_len < 56 {
            56 - self.buffer_len
        } else {
            120 - self.buffer_len
        };

        self.update(&padding[..pad_len]);
        self.update(&bit_len.to_le_bytes());

        let mut digest = [0u8; 16];
        for (chunk, value) in digest.chunks_exact_mut(4).zip(self.state) {
            chunk.copy_from_slice(&value.to_le_bytes());
        }

        digest
    }
}

fn transform(state: &mut [u32; 4], block: &[u8; 64]) {
    const S: [u32; 64] = [
        7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5,
        9, 14, 20, 5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10,
        15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21,
    ];
    const K: [u32; 64] = [
        0xd76a_a478,
        0xe8c7_b756,
        0x2420_70db,
        0xc1bd_ceee,
        0xf57c_0faf,
        0x4787_c62a,
        0xa830_4613,
        0xfd46_9501,
        0x6980_98d8,
        0x8b44_f7af,
        0xffff_5bb1,
        0x895c_d7be,
        0x6b90_1122,
        0xfd98_7193,
        0xa679_438e,
        0x49b4_0821,
        0xf61e_2562,
        0xc040_b340,
        0x265e_5a51,
        0xe9b6_c7aa,
        0xd62f_105d,
        0x0244_1453,
        0xd8a1_e681,
        0xe7d3_fbc8,
        0x21e1_cde6,
        0xc337_07d6,
        0xf4d5_0d87,
        0x455a_14ed,
        0xa9e3_e905,
        0xfcef_a3f8,
        0x676f_02d9,
        0x8d2a_4c8a,
        0xfffa_3942,
        0x8771_f681,
        0x6d9d_6122,
        0xfde5_380c,
        0xa4be_ea44,
        0x4bde_cfa9,
        0xf6bb_4b60,
        0xbebf_bc70,
        0x289b_7ec6,
        0xeaa1_27fa,
        0xd4ef_3085,
        0x0488_1d05,
        0xd9d4_d039,
        0xe6db_99e5,
        0x1fa2_7cf8,
        0xc4ac_5665,
        0xf429_2244,
        0x432a_ff97,
        0xab94_23a7,
        0xfc93_a039,
        0x655b_59c3,
        0x8f0c_cc92,
        0xffef_f47d,
        0x8584_5dd1,
        0x6fa8_7e4f,
        0xfe2c_e6e0,
        0xa301_4314,
        0x4e08_11a1,
        0xf753_7e82,
        0xbd3a_f235,
        0x2ad7_d2bb,
        0xeb86_d391,
    ];

    let mut words = [0u32; 16];
    for (word, bytes) in words.iter_mut().zip(block.chunks_exact(4)) {
        *word = u32::from_le_bytes(bytes.try_into().expect("4-byte word"));
    }

    let [mut a, mut b, mut c, mut d] = *state;

    for i in 0..64 {
        let (f, g) = match i {
            0..=15 => ((b & c) | (!b & d), i),
            16..=31 => ((d & b) | (!d & c), (5 * i + 1) % 16),
            32..=47 => (b ^ c ^ d, (3 * i + 5) % 16),
            _ => (c ^ (b | !d), (7 * i) % 16),
        };

        let next = a
            .wrapping_add(f)
            .wrapping_add(K[i])
            .wrapping_add(words[g])
            .rotate_left(S[i])
            .wrapping_add(b);
        a = d;
        d = c;
        c = b;
        b = next;
    }

    state[0] = state[0].wrapping_add(a);
    state[1] = state[1].wrapping_add(b);
    state[2] = state[2].wrapping_add(c);
    state[3] = state[3].wrapping_add(d);
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn hashes_known_md5_vectors() {
        assert_eq!(md5_hex(b""), "d41d8cd98f00b204e9800998ecf8427e");
        assert_eq!(md5_hex(b"abc"), "900150983cd24fb0d6963f7d28e17f72");
        assert_eq!(
            md5_hex(b"The quick brown fox jumps over the lazy dog"),
            "9e107d9d372bb6826bd81d3542a419d6"
        );
    }
}
