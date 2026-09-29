import build/head
import data/site.{type SiteMeta, AnalyticsDisabled, CommentsDisabled, SiteMeta}
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

fn site() -> SiteMeta {
  SiteMeta(
    base_url: "https://example.com",
    title: "Test Site",
    description: "A test site.",
    analytics: AnalyticsDisabled,
    comments: CommentsDisabled,
    fediverse_creator: None,
    rss_enabled: True,
  )
}

fn render(
  site: SiteMeta,
  page_title: Option(String),
  page_description: Option(String),
  page_path: String,
  custom_meta: List(head.MetaEntry),
) -> String {
  head.head_metadata(site, page_title, page_description, page_path, custom_meta)
}

fn assert_contains(haystack: String, needle: String) -> Nil {
  haystack
  |> string.contains(needle)
  |> should.be_true()
}

fn assert_not_contains(haystack: String, needle: String) -> Nil {
  haystack
  |> string.contains(needle)
  |> should.be_false()
}

fn count(haystack: String, needle: String) -> Int {
  haystack |> string.split(needle) |> list.length |> fn(n) { n - 1 }
}

pub fn emits_title_and_description_defaults_test() {
  let html = render(site(), None, None, "/", [])

  html
  |> should.equal(
    "<title>Test Site</title>"
    <> "<meta name='description' content='A test site.'>"
    <> "<meta property='og:title' content='Test Site'>"
    <> "<meta property='og:description' content='A test site.'>"
    <> "<meta property='og:url' content='https://example.com/'>"
    <> "<meta property='og:type' content='website'>",
  )
}

pub fn page_title_overrides_site_title_test() {
  let html = render(site(), Some("Post Title"), None, "/", [])

  assert_contains(html, "<title>Post Title</title>")
  assert_contains(html, "<meta property='og:title' content='Post Title'>")
}

pub fn page_description_overrides_site_description_test() {
  let html = render(site(), None, Some("Page desc"), "/", [])

  assert_contains(html, "<meta name='description' content='Page desc'>")
}

pub fn og_url_includes_page_path_test() {
  let html = render(site(), None, None, "/arata/", [])

  assert_contains(
    html,
    "<meta property='og:url' content='https://example.com/arata/'>",
  )
}

pub fn fediverse_meta_emitted_when_configured_test() {
  let html =
    render(
      SiteMeta(..site(), fediverse_creator: Some("@me@example.social")),
      None,
      None,
      "/",
      [],
    )

  assert_contains(
    html,
    "<meta name='fediverse:creator' content='@me@example.social'>",
  )
}

pub fn fediverse_meta_absent_by_default_test() {
  assert_not_contains(render(site(), None, None, "/", []), "fediverse")
}

pub fn custom_meta_suppresses_auto_generated_entries_test() {
  let html =
    render(site(), None, None, "/", [
      head.MetaEntry("description", "custom desc"),
      head.MetaEntry("og:title", "custom og"),
      head.MetaEntry("og:description", "custom og desc"),
    ])

  assert_contains(html, "<meta name='description' content='custom desc'>")
  assert_contains(html, "<meta property='og:title' content='custom og'>")
  assert_contains(
    html,
    "<meta property='og:description' content='custom og desc'>",
  )

  // The site defaults must not appear alongside the overrides.
  assert_not_contains(html, "content='A test site.'")
  assert_not_contains(html, "content='Test Site'")
}

pub fn custom_meta_is_appended_test() {
  let html = render(site(), None, None, "/", [head.MetaEntry("author", "Ada")])

  assert_contains(html, "<meta name='author' content='Ada'>")
}

pub fn og_keys_use_property_attribute_test() {
  let html = render(site(), None, None, "/", [])

  assert_contains(html, "<meta property='og:type' content='website'>")
}

pub fn non_og_keys_use_name_attribute_test() {
  let html = render(site(), None, None, "/", [])

  assert_contains(html, "<meta name='description' content='A test site.'>")
}

pub fn escapes_quotes_in_values_test() {
  let html =
    render(
      SiteMeta(
        ..site(),
        title: "Ada's \"Blog\"",
        description: "Loves <Gleam> & 'Lustre'",
      ),
      None,
      None,
      "/",
      [],
    )

  assert_contains(html, "<title>Ada&#39;s &quot;Blog&quot;</title>")
  assert_contains(
    html,
    "<meta name='description' content='Loves &lt;Gleam&gt; &amp; &#39;Lustre&#39;'>",
  )
}

pub fn escaping_prevents_attribute_breakout_test() {
  let html =
    render(site(), None, None, "/", [
      head.MetaEntry("og:title", "' onload='alert(1)"),
    ])

  assert_contains(
    html,
    "<meta property='og:title' content='&#39; onload=&#39;alert(1)'>",
  )

  // The injected attribute must not have become a real attribute.
  assert_not_contains(html, "onload='alert(1)'")
}

pub fn escaping_applies_to_fediverse_handle_test() {
  let html =
    render(
      SiteMeta(..site(), fediverse_creator: Some("'><script>")),
      None,
      None,
      "/",
      [],
    )

  assert_not_contains(html, "<script>")
  assert_contains(
    html,
    "<meta name='fediverse:creator' content='&#39;&gt;&lt;script&gt;'>",
  )
}

pub fn tag_counts_stay_balanced_test() {
  let html = render(site(), None, None, "/", [])

  // Five auto-generated meta tags. Only the final attribute of each tag is
  // followed by `>`, so there is exactly one `'>'` per tag.
  count(html, "<meta ") |> should.equal(5)
  count(html, "'>") |> should.equal(5)
  count(html, "<title>") |> should.equal(1)
}
