VERSION="20130618.03"
SSL_CERT_DIR=`pwd`/certs ./wget-lua \
--restrict-file-names=windows \
-e robots=off \
-U "Wget/1.14 gzip ArchiveTeam" \
--lua-script=greader-directory.lua \
--warc-file="test_download" \
--header='Accept-Encoding: gzip' \
--header='Cookie: $GOOGLE_COOKIE' \
--warc-header="operator: Archive Team" \
--warc-header="greader-directory-dld-script-version: $VERSION" \
"https://www.google.com/reader/directory/search?q=galaxy%20nexus"

# Google needs a "gzip" in the UA to believe our "Accept-Encoding: gzip", though other
# browser UAs should probably work.
