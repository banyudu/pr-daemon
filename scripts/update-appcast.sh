#!/bin/bash
set -euo pipefail

# Required env vars: VERSION, BUILD_NUMBER, ED_SIGNATURE, DMG_SIZE

DMG_URL="https://github.com/banyudu/pr-daemon/releases/download/v${VERSION}/PRDaemon-${VERSION}.dmg"
PUB_DATE=$(date -u +"%a, %d %b %Y %H:%M:%S %z")

ITEM="<item>
            <title>Version ${VERSION}</title>
            <sparkle:version>${BUILD_NUMBER}</sparkle:version>
            <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <pubDate>${PUB_DATE}</pubDate>
            <enclosure url=\"${DMG_URL}\" sparkle:edSignature=\"${ED_SIGNATURE}\" length=\"${DMG_SIZE}\" type=\"application/octet-stream\"/>
        </item>"

if [ -f appcast.xml ]; then
  # Insert new item before </channel>
  awk -v item="$ITEM" '/<\/channel>/ { print "        " item; } { print }' appcast.xml > appcast_tmp.xml
  mv appcast_tmp.xml appcast.xml
else
  cat > appcast.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>PR Daemon</title>
        <link>https://github.com/banyudu/pr-daemon</link>
        <description>PR Daemon updates</description>
        <language>en</language>
        ${ITEM}
    </channel>
</rss>
EOF
fi

echo "appcast.xml updated for v${VERSION}"
