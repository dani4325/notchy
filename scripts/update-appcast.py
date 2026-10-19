#!/usr/bin/env python3
import email.utils, pathlib, re, sys

appcast_path, version, build, url, signature_attrs, minimum = sys.argv[1:7]
path = pathlib.Path(appcast_path)
if path.exists():
    text = path.read_text()
else:
    text = """<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>Notchy</title>
  </channel>
</rss>
"""
text = re.sub(r"\s*<item>(?:(?!</item>).)*<sparkle:shortVersionString>" + re.escape(version) + r"</sparkle:shortVersionString>.*?</item>", "", text, flags=re.S)
item = f"""
    <item>
      <title>{version}</title>
      <pubDate>{email.utils.formatdate(usegmt=True)}</pubDate>
      <sparkle:version>{build}</sparkle:version>
      <sparkle:shortVersionString>{version}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{minimum}</sparkle:minimumSystemVersion>
      <enclosure url="{url}" type="application/octet-stream" {signature_attrs.strip()} />
    </item>"""
text = text.replace("<title>Notchy</title>", "<title>Notchy</title>" + item, 1)
path.write_text(text)
