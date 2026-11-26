//! `keybinds.conf` from the editor's side: lines stay where they are, the
//! bindings change, and the file goes back the way it was read. The names
//! match what `gameinput.rs` parses, exactly and case-sensitively.

use std::path::Path;

/// Every bindable action with its dot on the artwork (1254x1254 space,
/// where the marker picture put them).
pub const ACTIONS: [(&str, (f32, f32)); 24] = [
    ("A", (1003.0, 673.0)),
    ("B", (1111.0, 591.0)),
    ("X", (903.0, 593.0)),
    ("Y", (1010.0, 503.0)),
    ("LB", (223.0, 345.0)),
    ("RB", (1027.0, 341.0)),
    ("LS", (243.0, 629.0)),
    ("RS", (805.0, 818.0)),
    ("Start", (766.0, 593.0)),
    ("View", (490.0, 593.0)),
    ("Up", (435.0, 736.0)),
    ("Down", (436.0, 847.0)),
    ("Left", (368.0, 793.0)),
    ("Right", (507.0, 792.0)),
    ("LT", (283.0, 259.0)),
    ("RT", (970.0, 260.0)),
    ("LeftStickUp", (242.0, 571.0)),
    ("LeftStickDown", (245.0, 682.0)),
    ("LeftStickLeft", (177.0, 632.0)),
    ("LeftStickRight", (316.0, 628.0)),
    ("RightStickUp", (806.0, 764.0)),
    ("RightStickDown", (804.0, 871.0)),
    ("RightStickLeft", (745.0, 820.0)),
    ("RightStickRight", (874.0, 817.0)),
];

/// The one spelling each action answers to. `gameinput.rs` binds `Menu` and
/// `Start` to the same button, and `Back` and `View`, so the editor reads a
/// line under either name and shows it under the ACTIONS one.
fn canon(name: &str) -> &str {
    match name {
        "Menu" => "Start",
        "Back" => "View",
        other => other,
    }
}

/// The keys an action binds now, as written; empty when unbound or absent.
pub fn bound_keys(text: &str, action: &str) -> Vec<String> {
    let want = canon(action);
    for line in text.lines() {
        let body = line.split('#').next().unwrap_or("").trim();
        if let Some((name, keys)) = body.split_once('=')
            && canon(name.trim()) == want
        {
            return keys
                .split([' ', ','])
                .filter(|k| !k.is_empty())
                .map(str::to_owned)
                .collect();
        }
    }
    Vec::new()
}

/// Rewrites the action's line to bind exactly these keys, or adds one at
/// the end. Every action ends the call with one line: a duplicate of ours
/// goes, and so does a second line for any other action, since the editor
/// shows one binding and `gameinput.rs` keeps one winner per name anyway.
/// An empty list writes an empty value, which unbinds.
pub fn set_binding(text: &mut String, action: &str, keys: &[&str]) {
    let line = format!("{action} = {}", keys.join(" "));
    let want = canon(action);
    let mut replaced = false;
    let mut seen: Vec<&str> = Vec::new();
    let mut kept: Vec<String> = Vec::new();
    for old in text.lines() {
        let body = old.split('#').next().unwrap_or("").trim();
        match body.split_once('=') {
            Some((name, _)) => {
                let other = canon(name.trim());
                if other == want {
                    if !replaced {
                        kept.push(line.clone());
                        replaced = true;
                    }
                } else if seen.contains(&other) {
                    // A stale duplicate line for another action goes too.
                } else {
                    seen.push(other);
                    kept.push(old.to_owned());
                }
            }
            None => kept.push(old.to_owned()),
        }
    }
    if !replaced {
        kept.push(line);
    }
    let mut out = kept.join("\n");
    if !text.ends_with('\n') {
        out.push('\n');
    } else if !out.ends_with('\n') {
        out.push('\n');
    }
    *text = out;
}

/// The actions that light up when this key goes down; names compare as
/// `gameinput.rs` does, case-insensitively.
pub fn actions_for_key(text: &str, key: &str) -> Vec<&'static str> {
    ACTIONS
        .iter()
        .filter(|(action, _)| {
            bound_keys(text, action)
                .iter()
                .any(|k| k.eq_ignore_ascii_case(key))
        })
        .map(|(action, _)| *action)
        .collect()
}

/// Writes the file the way the game reads it: a partial file and a rename,
/// so the poll thread never catches a half-written mapping.
pub fn save(path: &Path, text: &str) -> anyhow::Result<()> {
    let tmp = path.with_extension("conf.partial");
    std::fs::write(&tmp, text)?;
    std::fs::rename(&tmp, path)?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn a_binding_rewrites_only_its_line() {
        let mut text = "# mine\nA = Enter\nB = Backspace\n".to_owned();
        set_binding(&mut text, "B", &["C"]);
        assert_eq!(text, "# mine\nA = Enter\nB = C\n");
        assert_eq!(bound_keys(&text, "A"), ["Enter"]);
        assert_eq!(bound_keys(&text, "B"), ["C"]);
    }

    #[test]
    fn a_missing_action_is_added_and_duplicates_gone() {
        let mut text = "A = Enter\nA = K\n".to_owned();
        set_binding(&mut text, "LT", &["Z"]);
        assert_eq!(text, "A = Enter\nLT = Z\n");
        assert_eq!(bound_keys(&text, "A"), ["Enter"]);
    }

    #[test]
    fn an_empty_binding_unbinds() {
        let mut text = "A = Enter\n".to_owned();
        set_binding(&mut text, "A", &[]);
        assert_eq!(text, "A = \n");
        assert!(bound_keys(&text, "A").is_empty());
    }

    #[test]
    fn a_key_names_every_action_wearing_it() {
        let text = "A = Enter\nMenu = Enter\nLeftStickUp = W\n";
        assert_eq!(actions_for_key(text, "Enter"), ["A", "Start"]);
        assert_eq!(actions_for_key(text, "enter"), ["A", "Start"]);
        assert_eq!(actions_for_key(text, "w"), ["LeftStickUp"]);
        assert!(actions_for_key(text, "Q").is_empty());
    }

    #[test]
    fn comments_do_not_count_as_bindings() {
        let text = "# A = Enter\nB = Backspace\n";
        assert!(bound_keys(text, "A").is_empty());
        assert!(actions_for_key(text, "Enter").is_empty());
    }
}
