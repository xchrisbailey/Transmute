#!/usr/bin/env python3
"""Check the published static-site boundary without third-party packages."""

from html.parser import HTMLParser
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1] / "site"


class Page(HTMLParser):
    def __init__(self, text):
        super().__init__()
        self.elements = []
        self.feed(text)

    def handle_starttag(self, tag, attrs):
        self.elements.append((tag, dict(attrs)))


class PublishedSiteTests(unittest.TestCase):
    def test_published_page_has_metadata_semantics_and_resolvable_local_links(self):
        html = (ROOT / "index.html").read_text()
        page = Page(html)
        elements = page.elements
        self.assertEqual(sum(tag == "h1" for tag, _ in elements), 1)
        self.assertEqual(sum(tag == "main" for tag, _ in elements), 1)
        self.assertIn(("html", {"lang": "en"}), elements)
        self.assertRegex(html, r"<title>[^<]+</title>")
        for name in ("description", "viewport"):
            self.assertTrue(any(a.get("name") == name and a.get("content") for _, a in elements))
        for name in ("og:title", "og:description", "og:image", "og:url"):
            self.assertTrue(any(a.get("property") == name and a.get("content") for _, a in elements))
        self.assertTrue(any(t == "link" and a.get("rel") == "canonical" for t, a in elements))
        self.assertTrue(any(t == "noscript" for t, _ in elements))
        self.assertTrue(any(a.get("aria-live") == "polite" for _, a in elements))
        ids = [a["id"] for _, a in elements if "id" in a]
        self.assertEqual(len(ids), len(set(ids)), "Duplicate anchor IDs")
        links = []
        for tag, attrs in elements:
            if tag == "img":
                self.assertIn("alt", attrs)
            for key in ("src", "href"):
                if key in attrs:
                    links.append((ROOT / "index.html", attrs[key]))
        for css in ROOT.rglob("*.css"):
            links.extend((css, ref) for ref in re.findall(r"url\(['\"]?([^)'\"]+)", css.read_text()))
        for source, ref in links:
            url = urlsplit(ref)
            if url.scheme or url.netloc:
                continue
            self.assertFalse(url.path.startswith("/"), f"Not project-Pages relative: {ref}")
            target = (source.parent / unquote(url.path)).resolve() if url.path else source
            self.assertTrue(target.is_relative_to(ROOT.resolve()), f"Escapes site: {ref}")
            self.assertTrue(target.is_file(), f"Missing local asset: {ref}")
            if url.fragment and target.suffix == ".html":
                target_ids = [a.get("id") for _, a in Page(target.read_text()).elements]
                self.assertIn(unquote(url.fragment), target_ids, f"Missing anchor: {ref}")
        self.assertIn("https://github.com/xchrisbailey/Transmute", html)

    def test_social_preview_is_a_published_local_image(self):
        page = Page((ROOT / "index.html").read_text())
        metadata = {a.get("property"): a.get("content") for t, a in page.elements if t == "meta"}
        canonical = next(a["href"] for t, a in page.elements if t == "link" and a.get("rel") == "canonical")
        self.assertEqual(metadata["og:url"], canonical)
        self.assertTrue(metadata["og:image"].startswith(canonical))
        image = ROOT / metadata["og:image"][len(canonical):]
        self.assertTrue(image.is_file(), "Social card must be inside the Pages artifact")
        self.assertTrue(image.read_bytes().startswith(b"\x89PNG\r\n\x1a\n"))


if __name__ == "__main__":
    unittest.main()
