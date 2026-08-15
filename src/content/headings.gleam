//// Build-time heading processing: parses mork-rendered HTML, assigns every
//// heading a deterministic, document-unique ID, and stitches the final IDs
//// back into the HTML while producing the nested table of contents.
////
//// This module is **build-time only**. It must NOT be imported by the SPA
//// entry chain (`arata.gleam`).
////
//// ## Slug policy
////
//// Heading IDs are readable Unicode-aware slugs derived from the heading
//// text via one centralized policy (`slugify`):
////
////   1. the text is lowercased;
////   2. whitespace, `-`, and `_` become a single `-` separator;
////   3. punctuation and symbols (ASCII, CJK, emoji, and other symbol blocks)
////      are removed;
////   4. letters, digits, and ideographs of any script (CJK, Cyrillic, Greek,
////      Hangul, …) are preserved;
////   5. consecutive separators collapse and leading/trailing separators are
////      trimmed.
////
//// If the resulting slug is empty (for example a heading that consists only
//// of punctuation or emoji), the heading receives a sequential `heading-N`
//// fallback ID. Fallback numbering is scoped to the current document.
////
//// ## Duplicate resolution
////
//// IDs are assigned in document order with document-level state:
////
////   - the first heading that normalizes to `foo` keeps the bare slug;
////   - the second becomes `foo-2`, the third `foo-3`, and so on;
////   - every assigned ID is tracked, so a heading that *naturally* slugifies
////     to an already-taken suffix (e.g. a title "Foo 2" colliding with the
////     second "Foo") is bumped to the next free number instead of colliding;
////   - the same Markdown input always produces the same IDs.
////
//// Because IDs are assigned from the full heading list before the ToC is
//// built (the ToC consumes every heading, h1–h6), enabling or disabling the
//// ToC never changes the generated IDs.

import data/post.{type TocEntry, TocEntry}
import gleam.{type UtfCodepoint}
import gleam/dict.{type Dict}
import gleam/int
import gleam/list
import gleam/result
import gleam/string

/// Process rendered HTML end to end: assign an ID to every heading, inject
/// the ID plus a permalink anchor into the HTML, and build the nested table
/// of contents (every heading level, h1–h6) from the same final IDs.
///
/// The rendered headings and the ToC links therefore consume exactly the same
/// ID, so every ToC target resolves to one rendered heading.
pub fn process(html: String) -> #(String, List(TocEntry)) {
  let assigned = assign_heading_ids(html)
  let html_with_ids = inject_ids(html, assigned)
  let toc = build_toc(assigned)
  #(html_with_ids, toc)
}

/// Assign an ID to every heading and inject the ID plus a permalink anchor
/// into the HTML, without building a table of contents. Used for pages,
/// which render headings but have no ToC in the content model.
pub fn process_ids_only(html: String) -> String {
  let assigned = assign_heading_ids(html)
  inject_ids(html, assigned)
}

/// Assign a final ID to every heading in `html`, in document order.
///
/// Each entry is a `#(level, id, title)` triple where `title` is the
/// HTML-tag-stripped heading text used by the ToC.
pub fn assign_heading_ids(html: String) -> List(#(Int, String, String)) {
  html
  |> parse_headings
  |> assign_ids
}

// SLUG POLICY ----------------------------------------------------------------

/// What to do with a single Unicode code point while slugifying.
type CodepointKind {
  /// Letters, digits, and ideographs — preserved verbatim.
  Keep
  /// Whitespace and hyphen-like characters — become a `-` separator.
  Separator
  /// Punctuation, symbols, and emoji — removed.
  Remove
}

/// The ASCII hyphen code point used as the slug separator.
const separator_codepoint = 45

/// Build the base slug for a heading title, without duplicate resolution.
///
/// This is the single source of truth for slug generation. It operates on
/// code points so CJK and other non-ASCII scripts survive, while punctuation,
/// symbols, and emoji are dropped by `codepoint_kind`.
pub fn slugify(text: String) -> String {
  text
  |> string.lowercase()
  |> string.to_utf_codepoints()
  |> list.fold([], fn(acc, codepoint) {
    case codepoint_kind(string.utf_codepoint_to_int(codepoint)) {
      Keep -> [codepoint, ..acc]
      Separator ->
        case acc {
          // Leading separators are skipped.
          [] -> acc
          // Consecutive separators collapse into one.
          [previous, ..] ->
            case string.utf_codepoint_to_int(previous) == separator_codepoint {
              True -> acc
              False -> [hyphen_codepoint(), ..acc]
            }
        }
      Remove -> acc
    }
  })
  |> drop_trailing_separators
  |> list.reverse
  |> string.from_utf_codepoints
}

/// A `UtfCodepoint` for the ASCII hyphen. `string.utf_codepoint` never fails
/// for a valid code point, so this cannot panic in practice.
fn hyphen_codepoint() -> UtfCodepoint {
  let assert Ok(codepoint) = string.utf_codepoint(separator_codepoint)
  codepoint
}

/// Drop trailing separators from a reversed code-point list. The list is
/// built by prepending, so its head is the last character of the final slug.
fn drop_trailing_separators(
  codepoints: List(UtfCodepoint),
) -> List(UtfCodepoint) {
  case codepoints {
    [first, ..rest] ->
      case string.utf_codepoint_to_int(first) == separator_codepoint {
        True -> drop_trailing_separators(rest)
        False -> codepoints
      }
    _ -> codepoints
  }
}

/// Classify a code point according to the centralized slug policy.
///
/// The policy is a denylist: everything that is not whitespace, punctuation,
/// or a symbol/emoji is preserved, so letters and ideographs of *any* script
/// survive slugification. The explicit checks cover ASCII punctuation, CJK
/// punctuation, general punctuation, symbols, arrows, and the main emoji
/// ranges.
fn codepoint_kind(codepoint: Int) -> CodepointKind {
  case codepoint {
    // Whitespace and hyphen-like characters become separators.
    9 | 10 | 13 | 32 | 45 | 95 | 0x00a0 | 0x3000 -> Separator
    _ -> classify_remaining(codepoint)
  }
}

/// Classify everything that is not whitespace/hyphen-like: the keep/remove
/// decision is a single place so the policy stays centralized.
fn classify_remaining(codepoint: Int) -> CodepointKind {
  let classification = #(
    is_ascii_letter_or_digit(codepoint),
    is_ascii_punctuation(codepoint),
    is_control_codepoint(codepoint),
    is_cjk_punctuation(codepoint),
    is_symbol_or_emoji(codepoint),
  )
  case classification {
    #(True, _, _, _, _) -> Keep
    #(False, True, _, _, _) -> Remove
    #(False, False, True, _, _) -> Remove
    #(False, False, False, True, _) -> Remove
    #(False, False, False, False, True) -> Remove
    // Everything else — letters, digits, and ideographs of any script — is
    // preserved.
    _ -> Keep
  }
}

fn is_ascii_letter_or_digit(codepoint: Int) -> Bool {
  { codepoint >= 48 && codepoint <= 57 }
  || { codepoint >= 65 && codepoint <= 90 }
  || { codepoint >= 97 && codepoint <= 122 }
}

fn is_ascii_punctuation(codepoint: Int) -> Bool {
  { codepoint >= 33 && codepoint <= 47 }
  || { codepoint >= 58 && codepoint <= 64 }
  || { codepoint >= 91 && codepoint <= 96 }
  || { codepoint >= 123 && codepoint <= 126 }
}

fn is_control_codepoint(codepoint: Int) -> Bool {
  { codepoint >= 0x0000 && codepoint <= 0x001f }
  || { codepoint >= 0x007f && codepoint <= 0x009f }
}

fn is_cjk_punctuation(codepoint: Int) -> Bool {
  { codepoint >= 0x3001 && codepoint <= 0x303f }
  || { codepoint >= 0xff00 && codepoint <= 0xffef }
}

/// Punctuation, symbols, arrows, and the main emoji blocks.
fn is_symbol_or_emoji(codepoint: Int) -> Bool {
  { codepoint >= 0x1f000 && codepoint <= 0x1faff }
  || { codepoint >= 0x1f1e6 && codepoint <= 0x1f1ff }
  || { codepoint >= 0x2600 && codepoint <= 0x27bf }
  || { codepoint >= 0x2b00 && codepoint <= 0x2bff }
  || { codepoint >= 0x2190 && codepoint <= 0x21ff }
  || { codepoint >= 0x2300 && codepoint <= 0x23ff }
  || { codepoint >= 0x2500 && codepoint <= 0x25ff }
  || codepoint == 0x200d
  || codepoint == 0x20e3
  || codepoint == 0xfe0f
  || { codepoint >= 0x2000 && codepoint <= 0x206f }
  || { codepoint >= 0x2100 && codepoint <= 0x214f }
  || { codepoint >= 0x2200 && codepoint <= 0x22ff }
  || { codepoint >= 0x2400 && codepoint <= 0x245f }
  || { codepoint >= 0x2460 && codepoint <= 0x24ff }
  || { codepoint >= 0x2a00 && codepoint <= 0x2aff }
  || { codepoint >= 0x2e00 && codepoint <= 0x2e7f }
}

// ID ASSIGNMENT --------------------------------------------------------------

/// Document-level state for ID assignment.
type IdState {
  IdState(
    /// How many times each base slug has been seen so far.
    counts: Dict(String, Int),
    /// Every ID already assigned in this document.
    used: Dict(String, Nil),
    /// Next `heading-N` number for headings with no usable slug.
    fallback_next: Int,
  )
}

/// Assign final IDs to raw headings in document order.
fn assign_ids(headings: List(RawHeading)) -> List(#(Int, String, String)) {
  let #(assigned, _state) =
    list.fold(headings, #([], new_id_state()), fn(acc, heading) {
      let #(acc_list, state) = acc
      let base = slugify(heading.title)
      let #(id, next_state) = claim_id(base, state)
      #([#(heading.level, id, heading.title), ..acc_list], next_state)
    })
  list.reverse(assigned)
}

fn new_id_state() -> IdState {
  IdState(counts: dict.new(), used: dict.new(), fallback_next: 1)
}

/// Claim the next ID for a heading with the given base slug, threading the
/// document state through. An empty base slug receives a `heading-N` fallback.
fn claim_id(base: String, state: IdState) -> #(String, IdState) {
  case base {
    "" -> claim_fallback(state)
    _ -> {
      let occurrence = dict.get(state.counts, base) |> result.unwrap(or: 0)
      let occurrence = occurrence + 1
      let state =
        IdState(..state, counts: dict.insert(state.counts, base, occurrence))
      claim_slug(base, occurrence, state)
    }
  }
}

/// Claim the next `heading-N` fallback ID, skipping any number already taken
/// by a heading that naturally slugified to the same form.
fn claim_fallback(state: IdState) -> #(String, IdState) {
  let candidate = "heading-" <> int.to_string(state.fallback_next)
  case dict.has_key(state.used, candidate) {
    True ->
      claim_fallback(IdState(..state, fallback_next: state.fallback_next + 1))
    False -> #(
      candidate,
      IdState(
        ..state,
        used: dict.insert(state.used, candidate, Nil),
        fallback_next: state.fallback_next + 1,
      ),
    )
  }
}

/// Claim the `occurrence`-th ID for a base slug: the first occurrence keeps
/// the bare slug, later ones get `-2`, `-3`, … suffixes. When a suffix is
/// already taken (e.g. by a heading that naturally slugified to `foo-2`),
/// the next number is tried.
fn claim_slug(
  base: String,
  occurrence: Int,
  state: IdState,
) -> #(String, IdState) {
  let candidate = case occurrence == 1 {
    True -> base
    False -> base <> "-" <> int.to_string(occurrence)
  }
  case dict.has_key(state.used, candidate) {
    True -> claim_slug(base, occurrence + 1, state)
    False -> #(
      candidate,
      IdState(..state, used: dict.insert(state.used, candidate, Nil)),
    )
  }
}

// HTML INJECTION -------------------------------------------------------------

/// Inject the final IDs and permalink anchors into the rendered HTML.
///
/// The HTML is split on `<h` and zipped with the assigned IDs in document
/// order. Both the parser and this injector use the same heading-piece
/// detection, so the lists always line up; a heading piece consumes the next
/// ID, any other piece passes through unchanged.
fn inject_ids(html: String, assigned: List(#(Int, String, String))) -> String {
  let pieces = string.split(html, "<h")
  case pieces {
    [] -> html
    [first, ..rest] -> {
      let ids =
        list.map(assigned, fn(entry) {
          let #(_, id, _) = entry
          id
        })
      string.join([first, ..zip_pieces(rest, ids)], "<h")
    }
  }
}

/// Zip the pieces produced by splitting on `<h` with the assigned IDs.
fn zip_pieces(pieces: List(String), ids: List(String)) -> List(String) {
  case pieces, ids {
    [], _ -> []
    [piece, ..rest], [] -> [piece, ..zip_pieces(rest, [])]
    [piece, ..rest], [id, ..id_rest] ->
      case is_heading_piece(piece) {
        True -> [inject_heading_id(piece, id), ..zip_pieces(rest, id_rest)]
        False -> [piece, ..zip_pieces(rest, [id, ..id_rest])]
      }
  }
}

/// Whether a piece produced by splitting on `<h` is a heading element
/// (`<h1>`–`<h6>`). Mirrors `parse_heading_piece` so parsing and injection
/// stay consistent.
fn is_heading_piece(piece: String) -> Bool {
  case string.pop_grapheme(piece) {
    Error(_) -> False
    Ok(#(level_ch, rest)) ->
      case int.parse(level_ch) {
        Ok(level) if level >= 1 && level <= 6 ->
          case string.split_once(rest, ">") {
            Ok(#(_, title_with_rest)) ->
              result.is_ok(string.split_once(title_with_rest, "</h"))
            Error(_) -> False
          }
        _ -> False
      }
  }
}

/// Rewrite one heading piece `<hN>Title</hN>` as
/// `<hN id="id"><a href="#id">Title</a></hN>`.
fn inject_heading_id(piece: String, id: String) -> String {
  case string.split_once(piece, ">") {
    Ok(#(opening, rest)) ->
      case string.split_once(rest, "</h") {
        Ok(#(title, after_close)) ->
          opening
          <> " id=\""
          <> id
          <> "\"><a href=\"#"
          <> id
          <> "\">"
          <> title
          <> "</a></h"
          <> after_close
        Error(_) -> piece
      }
    Error(_) -> piece
  }
}

// PARSING --------------------------------------------------------------------

/// A heading parsed from rendered HTML, before any ID has been assigned.
type RawHeading {
  RawHeading(level: Int, title: String)
}

/// Parse `<hN>Title</hN>` tags out of rendered HTML (without IDs — mork emits
/// headings bare because `heading_ids` is disabled). `title` is the inner
/// HTML with tags stripped, which is what the slug and the ToC use.
fn parse_headings(html: String) -> List(RawHeading) {
  html
  |> string.split("<h")
  |> list.filter_map(parse_heading_piece)
}

fn parse_heading_piece(piece: String) -> Result(RawHeading, Nil) {
  use #(level_ch, rest) <- result.try(string.pop_grapheme(piece))
  use level <- result.try(int.parse(level_ch))
  case level >= 1 && level <= 6 {
    False -> Error(Nil)
    True -> {
      use #(_, title_with_rest) <- result.try(string.split_once(rest, ">"))
      use #(title, _) <- result.try(string.split_once(title_with_rest, "</h"))
      Ok(RawHeading(level: level, title: strip_html_tags(title)))
    }
  }
}

/// Strip HTML tags from a fragment of HTML.
fn strip_html_tags(html: String) -> String {
  html
  |> string.split("<")
  |> list.map(fn(piece) {
    case string.split_once(piece, ">") {
      Ok(#(_tag, rest)) -> rest
      Error(_) -> piece
    }
  })
  |> string.join("")
}

// TABLE OF CONTENTS ----------------------------------------------------------

/// Build a nested `TocEntry` tree from the assigned headings. Every level
/// (h1–h6) is part of the ToC: each heading nests under the nearest preceding
/// heading with a shallower level, and a heading with no shallower heading
/// before it (for example a leading h3 before any h2) becomes a top-level
/// entry. The tree preserves document order, so the view can render the
/// entries flat and derive each one's indentation from its own level.
///
/// The tree tolerates malformed heading order: a heading shallower than the
/// level currently being built (for example an h3 before the first h2, or an
/// h3 after an h4) re-anchors the build at that shallower level instead of
/// dropping the remaining headings, so no ToC section is ever lost.
fn build_toc(headings: List(#(Int, String, String))) -> List(TocEntry) {
  build_toc_tree(headings)
}

/// Build a nested `TocEntry` tree from a flat list of `(level, id, title)`
/// triples.
fn build_toc_tree(headings: List(#(Int, String, String))) -> List(TocEntry) {
  case headings {
    [] -> []
    [first, ..] -> {
      let #(first_level, _, _) = first
      build_at_level(headings, first_level)
    }
  }
}

/// Process `headings` at `level`, returning a list of `TocEntry`.
fn build_at_level(
  headings: List(#(Int, String, String)),
  level: Int,
) -> List(TocEntry) {
  case headings {
    [] -> []
    [#(lvl, id, title), ..rest] if lvl == level -> {
      let #(children_headings, siblings) = take_until_at_or_below(rest, level)
      let children = case children_headings {
        [] -> []
        [#(child_level, _, _), ..] ->
          build_at_level(children_headings, child_level)
      }
      let entry = TocEntry(level: lvl, id: id, title: title, children: children)
      [entry, ..build_at_level(siblings, level)]
    }
    // A heading shallower than the level being built re-anchors the tree at
    // its own level instead of stopping: a leading h3/h4 (before any h2) is
    // promoted to a top-level entry, and after the first h2 every subsequent
    // section builds normally.
    [#(lvl, _, _), ..] if lvl < level -> build_at_level(headings, lvl)
    [_, ..rest] -> build_at_level(rest, level)
  }
}

/// Split `headings` at the first entry whose level is `<= level`.
fn take_until_at_or_below(
  headings: List(#(Int, String, String)),
  level: Int,
) -> #(List(#(Int, String, String)), List(#(Int, String, String))) {
  case headings {
    [] -> #([], [])
    [#(lvl, _, _), ..] if lvl <= level -> #([], headings)
    [h, ..rest] -> {
      let #(children, siblings) = take_until_at_or_below(rest, level)
      #([h, ..children], siblings)
    }
  }
}
