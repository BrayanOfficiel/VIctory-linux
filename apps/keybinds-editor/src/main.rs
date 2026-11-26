//! The `keybinds.conf` editor: the pad picture with a clickable box per
//! action, wired to its dot by a line. Click a box, press a key, the file
//! is written; press a key with no box selected and the actions wearing it
//! light up. Native Rust (eframe/egui), no web stack.

mod conf;

use std::path::PathBuf;
use std::time::Duration;

use conf::ACTIONS;
use egui::{
    Align, Align2, Color32, FontId, Pos2, Rect, Sense, Stroke, StrokeKind, TextureHandle,
    TextureOptions, pos2,
};

/// The box size and the two columns it stacks in, twelve each.
const CHIP_W: f32 = 200.0;
const CHIP_H: f32 = 34.0;
const GAP: f32 = 8.0;

/// The columns follow their dots' height, so the lines fan out instead of
/// crossing: twelve rows, each box level with the band of dots it serves.
const LEFT_COLUMN: [&str; 12] = [
    "LT",
    "LB",
    "LeftStickUp",
    "View",
    "LeftStickRight",
    "LS",
    "LeftStickLeft",
    "LeftStickDown",
    "Up",
    "Right",
    "Left",
    "Down",
];
const RIGHT_COLUMN: [&str; 12] = [
    "RT",
    "RB",
    "Y",
    "B",
    "X",
    "Start",
    "A",
    "RightStickUp",
    "RightStickRight",
    "RS",
    "RightStickLeft",
    "RightStickDown",
];

const INK: Color32 = Color32::from_rgb(31, 36, 48);
const GRAY: Color32 = Color32::from_rgb(122, 129, 140);
const LINE: Color32 = Color32::from_rgb(107, 118, 134);
const GOLD: Color32 = Color32::from_rgb(212, 160, 23);
const FLASH: Color32 = Color32::from_rgb(255, 0, 255);

/// The repo's `keybinds.conf`: the one beside `keybinds.example.conf`, found
/// by walking up from wherever the editor was started. Everything keybinds
/// lives inside the VIctory-linux folder; a plain `keybinds.conf` relative
/// path would drop one in `apps/keybinds-editor/` when run from there.
fn repo_conf() -> PathBuf {
    let mut dir = std::env::current_dir().unwrap_or_else(|_| PathBuf::from("."));
    loop {
        if dir.join("keybinds.example.conf").is_file() {
            return dir.join("keybinds.conf");
        }
        if !dir.pop() {
            return PathBuf::from("keybinds.conf");
        }
    }
}

struct Editor {
    path: PathBuf,
    text: String,
    texture: TextureHandle,
    /// The box listening for a key, if any.
    selected: Option<&'static str>,
    /// Actions lit by a keypress with no box selected, and when it ends.
    flash: Vec<&'static str>,
    flash_until: f64,
    status: String,
}

impl Editor {
    fn new(cc: &eframe::CreationContext<'_>) -> Editor {
        let png = include_bytes!("../assets/controller.png");
        let decoded = image::load_from_memory(png)
            .expect("the shipped picture decodes")
            .to_rgba8();
        let (w, h) = decoded.dimensions();
        let color =
            egui::ColorImage::from_rgba_unmultiplied([w as usize, h as usize], decoded.as_raw());
        let texture = cc.egui_ctx.load_texture("controller", color, TextureOptions::default());
        let path = std::env::args()
            .nth(1)
            .map(PathBuf::from)
            .or_else(|| std::env::var_os("VICTORY_KEYBINDS").map(PathBuf::from))
            .unwrap_or_else(repo_conf);
        let text = std::fs::read_to_string(&path)
            .unwrap_or_else(|_| include_str!("../../../keybinds.example.conf").to_owned());
        Editor {
            path,
            text,
            texture,
            selected: None,
            flash: Vec::new(),
            flash_until: 0.0,
            status: String::new(),
        }
    }

    /// The dot an action's line ends at, in panel space.
    fn anchor(image: Rect, scale: f32, action: &str) -> Pos2 {
        let (x, y) = ACTIONS
            .iter()
            .find(|(a, _)| *a == action)
            .map_or((627.0, 627.0), |(_, p)| *p);
        pos2(image.min.x + x * scale, image.min.y + y * scale)
    }

    /// The boxes for this frame: name, rectangle, dot.
    fn chips(panel: Rect, image: Rect, scale: f32) -> Vec<(&'static str, Rect, Pos2)> {
        let mut out = Vec::with_capacity(ACTIONS.len());
        for (names, x) in [
            (&LEFT_COLUMN[..], panel.min.x + 12.0),
            (&RIGHT_COLUMN[..], panel.max.x - 12.0 - CHIP_W),
        ] {
            for (row, name) in names.iter().enumerate() {
                let top = image.min.y + row as f32 * (CHIP_H + GAP);
                let r = Rect::from_min_max(pos2(x, top), pos2(x + CHIP_W, top + CHIP_H));
                out.push((*name, r, Self::anchor(image, scale, name)));
            }
        }
        out
    }

    fn bind(&mut self, action: &'static str, key: &str) {
        conf::set_binding(&mut self.text, action, &[key]);
        self.write();
        self.status = format!("saved {action} = {key}");
        self.selected = None;
    }

    fn unbind(&mut self, action: &'static str) {
        conf::set_binding(&mut self.text, action, &[]);
        self.write();
        self.status = format!("saved {action} = (unbound)");
        self.selected = None;
    }

    fn write(&mut self) {
        if let Err(e) = conf::save(&self.path, &self.text) {
            self.status = format!("could not write {}: {e}", self.path.display());
        }
    }
}

impl eframe::App for Editor {
    fn update(&mut self, ctx: &egui::Context, _frame: &mut eframe::Frame) {
        let now = ctx.input(|i| i.time);
        if self.flash_until > 0.0 && now > self.flash_until {
            self.flash.clear();
            self.flash_until = 0.0;
        }

        // One key this frame, no combos: modifiers held alongside are ignored.
        let pressed = ctx.input(|i| {
            i.events.iter().find_map(|e| {
                if let egui::Event::Key {
                    key,
                    pressed: true,
                    repeat: false,
                    ..
                } = e
                {
                    key_name(*key)
                } else {
                    None
                }
            })
        });

        if let Some(key) = pressed {
            if let Some(action) = self.selected {
                self.bind(action, key);
            } else {
                self.flash = conf::actions_for_key(&self.text, key);
                if !self.flash.is_empty() {
                    self.flash_until = now + 1.2;
                }
                self.status = if self.flash.is_empty() {
                    format!("{key} binds nothing")
                } else {
                    format!("{key} lights: {}", self.flash.join(", "))
                };
            }
            ctx.request_repaint();
        }
        if self.flash_until > now {
            ctx.request_repaint_after(Duration::from_millis(120));
        }

        egui::TopBottomPanel::top("bar").show(ctx, |ui| {
            ui.horizontal(|ui| {
                ui.label(format!(
                    "{} - click a box, press a key; right-click unbinds",
                    self.path.display()
                ));
                if !self.status.is_empty() {
                    ui.with_layout(egui::Layout::right_to_left(Align::Center), |ui| {
                        ui.colored_label(GRAY, &self.status);
                    });
                }
            });
        });

        egui::CentralPanel::default().show(ctx, |ui| {
            let panel = ui.max_rect();
            let (response, painter) = ui.allocate_painter(panel.size(), Sense::click());

            // The pad, scaled to fit between the columns.
            let avail_w = panel.width() - 2.0 * (CHIP_W + 24.0);
            let avail_h = panel.height() - 16.0;
            let scale = (avail_w / 1254.0).min(avail_h / 1254.0);
            let side = 1254.0 * scale;
            let image = Rect::from_min_max(
                pos2(panel.center().x - side / 2.0, panel.min.y + 8.0),
                pos2(panel.center().x + side / 2.0, panel.min.y + 8.0 + side),
            );
            let uv = Rect::from_min_max(pos2(0.0, 0.0), pos2(1.0, 1.0));
            painter.image(self.texture.id(), image, uv, Color32::WHITE);

            for (action, chip, anchor) in Self::chips(panel, image, scale) {
                let selected = self.selected == Some(action);
                let flashing = self.flash.contains(&action);
                let stroke = if selected {
                    Stroke::new(2.5_f32, GOLD)
                } else if flashing {
                    Stroke::new(2.5_f32, FLASH)
                } else {
                    Stroke::new(1.0_f32, LINE)
                };
                let fill = if selected {
                    Color32::from_rgb(250, 240, 200)
                } else if flashing {
                    Color32::from_rgb(255, 205, 255)
                } else {
                    Color32::from_rgb(250, 250, 252)
                };
                painter.rect_filled(chip, 8.0, fill);
                painter.rect_stroke(chip, 8.0, stroke, StrokeKind::Inside);
                let keys = conf::bound_keys(&self.text, action);
                let bound = if keys.is_empty() {
                    "-".to_owned()
                } else {
                    keys.join(", ")
                };
                painter.text(
                    pos2(chip.min.x + 10.0, chip.center().y),
                    Align2::LEFT_CENTER,
                    action,
                    FontId::proportional(14.0),
                    INK,
                );
                if selected {
                    painter.text(
                        chip.center(),
                        Align2::CENTER_CENTER,
                        "press a key...",
                        FontId::proportional(13.0),
                        GOLD,
                    );
                } else {
                    painter.text(
                        pos2(chip.max.x - 10.0, chip.center().y),
                        Align2::RIGHT_CENTER,
                        bound,
                        FontId::monospace(13.0),
                        INK,
                    );
                }

                // The line: out of the chip's inner edge, then to the dot.
                let left_side = chip.center().x < panel.center().x;
                let inner = if left_side {
                    pos2(chip.max.x, chip.center().y)
                } else {
                    pos2(chip.min.x, chip.center().y)
                };
                let elbow = pos2(inner.x + if left_side { 24.0 } else { -24.0 }, inner.y);
                let color = if flashing {
                    FLASH
                } else if selected {
                    GOLD
                } else {
                    LINE
                };
                painter.line_segment([inner, elbow], Stroke::new(1.5_f32, color));
                painter.line_segment([elbow, anchor], Stroke::new(1.5_f32, color));
                painter.circle_filled(anchor, if flashing || selected { 6.0 } else { 4.0 }, color);
            }

            // Clicks land on whichever box holds the pointer; a click
            // beside the boxes drops the selection.
            if response.clicked() || response.secondary_clicked() {
                if let Some(pos) = response.interact_pointer_pos() {
                    let hit = Self::chips(panel, image, scale)
                        .into_iter()
                        .find(|(_, chip, _)| chip.contains(pos));
                    match hit {
                        Some((action, _, _)) if response.secondary_clicked() => self.unbind(action),
                        Some((action, _, _)) => {
                            self.selected = (self.selected != Some(action)).then_some(action);
                        }
                        None => self.selected = None,
                    }
                }
            }
        });
    }
}

/// The key's name in `keybinds.conf` spelling; None for keys the file
/// cannot hold.
fn key_name(key: egui::Key) -> Option<&'static str> {
    Some(match key {
        egui::Key::A => "A",
        egui::Key::B => "B",
        egui::Key::C => "C",
        egui::Key::D => "D",
        egui::Key::E => "E",
        egui::Key::F => "F",
        egui::Key::G => "G",
        egui::Key::H => "H",
        egui::Key::I => "I",
        egui::Key::J => "J",
        egui::Key::K => "K",
        egui::Key::L => "L",
        egui::Key::M => "M",
        egui::Key::N => "N",
        egui::Key::O => "O",
        egui::Key::P => "P",
        egui::Key::Q => "Q",
        egui::Key::R => "R",
        egui::Key::S => "S",
        egui::Key::T => "T",
        egui::Key::U => "U",
        egui::Key::V => "V",
        egui::Key::W => "W",
        egui::Key::X => "X",
        egui::Key::Y => "Y",
        egui::Key::Z => "Z",
        egui::Key::Num0 => "0",
        egui::Key::Num1 => "1",
        egui::Key::Num2 => "2",
        egui::Key::Num3 => "3",
        egui::Key::Num4 => "4",
        egui::Key::Num5 => "5",
        egui::Key::Num6 => "6",
        egui::Key::Num7 => "7",
        egui::Key::Num8 => "8",
        egui::Key::Num9 => "9",
        egui::Key::Enter => "Enter",
        egui::Key::Escape => "Esc",
        egui::Key::Tab => "Tab",
        egui::Key::Backspace => "Backspace",
        egui::Key::Space => "Space",
        egui::Key::ArrowUp => "Up",
        egui::Key::ArrowDown => "Down",
        egui::Key::ArrowLeft => "Left",
        egui::Key::ArrowRight => "Right",
        egui::Key::Home => "Home",
        egui::Key::End => "End",
        egui::Key::PageUp => "PageUp",
        egui::Key::PageDown => "PageDown",
        egui::Key::Insert => "Insert",
        egui::Key::Delete => "Delete",
        egui::Key::F1 => "F1",
        egui::Key::F2 => "F2",
        egui::Key::F3 => "F3",
        egui::Key::F4 => "F4",
        egui::Key::F5 => "F5",
        egui::Key::F6 => "F6",
        egui::Key::F7 => "F7",
        egui::Key::F8 => "F8",
        egui::Key::F9 => "F9",
        egui::Key::F10 => "F10",
        egui::Key::F11 => "F11",
        egui::Key::F12 => "F12",
        _ => return None,
    })
}

fn main() -> eframe::Result {
    let options = eframe::NativeOptions {
        viewport: egui::ViewportBuilder::default().with_inner_size([1500.0, 900.0]),
        ..Default::default()
    };
    eframe::run_native(
        "VIctory keybinds editor",
        options,
        Box::new(|cc| Ok(Box::new(Editor::new(cc)))),
    )
}
