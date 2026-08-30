//// Tests for markdown rendering (`data/markdown.gleam`), focusing on the
//// table wrapping step of `to_html`: every rendered `<table>` gets a
//// scrollable `.table-wrap` wrapper, nested tables each find their own
//// wrapper, escaped code samples are untouched, and unbalanced markup passes
//// through unchanged.

import data/markdown
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

const wrap_open = "<div class=\"table-wrap\">"

// WRAPPING --------------------------------------------------------------------

pub fn plain_table_is_wrapped_test() {
  markdown.wrap_tables("<table><tr><td>a</td></tr></table>")
  |> should.equal(wrap_open <> "<table><tr><td>a</td></tr></table></div>")
}

pub fn markdown_style_table_with_attributes_is_wrapped_test() {
  let html = "<table>\n<thead>\n<th>h</th>\n</thead>\n</table>"
  markdown.wrap_tables(html)
  |> should.equal(wrap_open <> html <> "</div>")
}

pub fn text_around_the_table_is_preserved_test() {
  let html = "<p>before</p><table><td>x</td></table><p>after</p>"
  markdown.wrap_tables(html)
  |> should.equal(
    "<p>before</p>"
    <> wrap_open
    <> "<table><td>x</td></table></div>"
    <> "<p>after</p>",
  )
}

pub fn multiple_tables_are_wrapped_independently_test() {
  let html = "<table><td>1</td></table><table><td>2</td></table>"
  markdown.wrap_tables(html)
  |> should.equal(
    wrap_open
    <> "<table><td>1</td></table></div>"
    <> wrap_open
    <> "<table><td>2</td></table></div>",
  )
}

pub fn nested_tables_each_get_their_own_wrapper_test() {
  let html = "<table><td><table><td>inner</td></table></td></table>"
  markdown.wrap_tables(html)
  |> should.equal(
    wrap_open
    <> "<table><td>"
    <> wrap_open
    <> "<table><td>inner</td></table></div>"
    <> "</td></table></div>",
  )
}

// NON-MATCHES -----------------------------------------------------------------

pub fn html_without_tables_is_unchanged_test() {
  let html = "<p>no tables here</p><ul><li>list</li></ul>"
  markdown.wrap_tables(html)
  |> should.equal(html)
}

pub fn empty_html_is_unchanged_test() {
  markdown.wrap_tables("")
  |> should.equal("")
}

pub fn escaped_table_in_code_is_not_wrapped_test() {
  let html = "<pre><code>&lt;table&gt;</code></pre>"
  markdown.wrap_tables(html)
  |> should.equal(html)
}

pub fn table_word_in_text_is_not_matched_test() {
  let html = "<p>the word table appears here</p><p>tablet</p>"
  markdown.wrap_tables(html)
  |> should.equal(html)
}

// EDGE CASES ------------------------------------------------------------------

pub fn unbalanced_table_is_left_untouched_test() {
  let html = "<table><tr><td>never closed</td></tr>"
  markdown.wrap_tables(html)
  |> should.equal(html)
}

pub fn nested_unbalanced_table_is_left_untouched_test() {
  let html = "<table><td><table><td>inner</td></table>"
  markdown.wrap_tables(html)
  |> should.equal(html)
}

pub fn wrapping_is_idempotent_test() {
  let html = "<table><td>a</td></table>"
  let wrapped = markdown.wrap_tables(html)
  markdown.wrap_tables(wrapped)
  |> should.equal(wrapped)
}

pub fn pre_wrapped_table_is_not_double_wrapped_test() {
  let html = wrap_open <> "<table><td>a</td></table></div>"
  markdown.wrap_tables(html)
  |> should.equal(html)
}

// INTEGRATION WITH HEADING PROCESSING -----------------------------------------

pub fn wrapping_composes_with_heading_processing_test() {
  // The loader pipeline is markdown.to_html -> headings.process; heading
  // injection must still work on the table-wrapped HTML that to_html emits.
  let html = markdown.to_html("## Title\n\n| a | b |\n| - | - |\n| 1 | 2 |")

  html
  |> should.equal(
    "<h2>Title</h2>\n"
    <> wrap_open
    <> "<table>\n<thead>\n<tr>\n<th>a</th>\n<th>b</th>\n</tr>\n</thead>\n<tbody>\n<tr>\n<td>1</td>\n<td>2</td>\n</tr>\n</tbody>\n</table></div>\n",
  )
  string.contains(html, "<table")
  |> should.be_true
}
