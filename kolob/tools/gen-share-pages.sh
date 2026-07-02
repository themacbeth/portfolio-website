#!/bin/sh
# Generates kolob/s/NNN.html — one share-stub page per invocation.
# Each stub carries per-token OG tags (image: ../share/og-NNN.jpg) and
# immediately redirects to the live renderer (../token.html?inv=N).
# Re-run after changing titles/descriptions:  sh kolob/tools/gen-share-pages.sh
cd "$(dirname "$0")/.." || exit 1
mkdir -p s

names="Oleblish Enish-go-on-dosh Kai-e-vanrash Lindi Zip Vusel Vauiste Waine Way-ho-ox-oan Oansli Kible Shineflis Flis Os Ondi"

i=0
while [ $i -le 143 ]; do
  pad=$(printf '%03d' $i)
  if [ $i -lt 3 ]; then
    name=$(echo $names | cut -d' ' -f$((i+1)))
    title="$name · KOLOB"
    desc="A great sun of the KOLOB triangle. Fully on-chain, drawn live from Ethereum."
  elif [ $i -lt 15 ]; then
    name=$(echo $names | cut -d' ' -f$((i+1)))
    title="$name · KOLOB"
    desc="One of the 12 governing systems of KOLOB. Fully on-chain, authored by its holder."
  else
    tn=$(printf '%03d' $((i-15)))
    title="Throne $tn · KOLOB"
    desc="One of 129 living thrones. A unique solar system, drawn live from its on-chain hash."
  fi
  cat > "s/$pad.html" <<EOF
<!doctype html><html lang="en"><head><meta charset="utf-8">
<title>$title</title>
<meta property="og:type" content="website">
<meta property="og:site_name" content="KOLOB">
<meta property="og:title" content="$title">
<meta property="og:description" content="$desc">
<meta property="og:image" content="https://macbeth.gallery/kolob/share/og-$pad.jpg">
<meta property="og:url" content="https://macbeth.gallery/kolob/s/$pad.html">
<meta name="twitter:card" content="summary_large_image">
<meta name="twitter:title" content="$title">
<meta name="twitter:description" content="$desc">
<meta name="twitter:image" content="https://macbeth.gallery/kolob/share/og-$pad.jpg">
<meta http-equiv="refresh" content="0;url=../token.html?inv=$i">
</head><body style="background:#000"></body></html>
EOF
  i=$((i+1))
done
echo "wrote s/000.html … s/143.html"
