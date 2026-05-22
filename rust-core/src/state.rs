//! Port của `TiengVietState.swift` sang Rust. Phase 1: data structure +
//! parser cơ bản (append-only). Phase 2 sẽ thêm validator; Phase 3 transformer.

/// Tone mark (dấu thanh). Mirror của Swift `DauThanh`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Tone {
    Bang,  // không dấu
    Sac,   // ́
    Huyen, // ̀
    Hoi,   // ̉
    Nga,   // ̃
    Nang,  // ̣
}

/// Diacritic (dấu mũ / móc). Mirror của Swift `DauMu`.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Diacritic {
    None,
    Mu,   // â, ê, ô
    Moc,  // ơ, ư
    TranA, // ă
}

/// Immutable typing state — mirror của TiengVietState. Trong Rust dùng
/// mutation in-place vì hot loop; nhưng giữ API ngữ nghĩa "create new" qua
/// `clone()` (cheap với Vec<char>).
#[derive(Clone, Debug, Default)]
pub struct State {
    raw: Vec<char>,
    pub tone: Tone,
    pub diacritic: Diacritic,
    pub gach_d: bool,
}

impl Default for Tone {
    fn default() -> Self {
        Tone::Bang
    }
}

impl Default for Diacritic {
    fn default() -> Self {
        Diacritic::None
    }
}

impl State {
    pub fn empty() -> Self {
        Self::default()
    }

    pub fn is_blank(&self) -> bool {
        self.raw.is_empty()
    }

    /// Append a character. Phase 1: chỉ append (parser sẽ refactor sau).
    pub fn push_char(&mut self, ch: char) {
        self.raw.push(ch);
    }

    /// Raw bytes (UTF-8) — dùng để FFI export ra Swift.
    pub fn raw_bytes(&self) -> Vec<u8> {
        let s: String = self.raw.iter().collect();
        s.into_bytes()
    }

    /// Phase 1 stub — always false. Phase 2 sẽ port logic từ
    /// `TiengVietValidator.needsRecovery`.
    pub fn needs_recovery(&self) -> bool {
        false
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn empty_state_is_blank() {
        let s = State::empty();
        assert!(s.is_blank());
        assert_eq!(s.tone, Tone::Bang);
        assert_eq!(s.diacritic, Diacritic::None);
        assert!(!s.gach_d);
    }

    #[test]
    fn push_appends_chars() {
        let mut s = State::empty();
        s.push_char('a');
        s.push_char('b');
        s.push_char('c');
        assert!(!s.is_blank());
        assert_eq!(s.raw_bytes(), b"abc");
    }
}
