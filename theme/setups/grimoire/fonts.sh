#!/bin/sh
# Grimoire's fonts (all SIL Open Font License, from Google Fonts' repository), into
# ~/.local/share/fonts/grimoire: UnifrakturMaguntia (blackletter), Uncial Antiqua, Cardo (book
# text), Cinzel + Cinzel Decorative (engraved caps), IBM Plex Mono (the terminal), Noto Sans Runic
# (the runes), Noto Sans Symbols 1 and 2 (alchemical signs, fleurons). Run once on a new machine.
# Headings use Cormorant Garamond: sudo pacman -S otf-cormorant
d="$HOME/.local/share/fonts/grimoire"
base=https://github.com/google/fonts/raw/main/ofl
mkdir -p "$d"
for f in unifrakturmaguntia/UnifrakturMaguntia-Book.ttf uncialantiqua/UncialAntiqua-Regular.ttf \
         cardo/Cardo-Regular.ttf cardo/Cardo-Bold.ttf cardo/Cardo-Italic.ttf \
         notosansrunic/NotoSansRunic-Regular.ttf \
         ibmplexmono/IBMPlexMono-Regular.ttf ibmplexmono/IBMPlexMono-Italic.ttf ibmplexmono/IBMPlexMono-Bold.ttf \
         ibmplexmono/IBMPlexMono-BoldItalic.ttf ibmplexmono/IBMPlexMono-Medium.ttf ibmplexmono/IBMPlexMono-SemiBold.ttf \
         'cinzel/Cinzel%5Bwght%5D.ttf' cinzeldecorative/CinzelDecorative-Regular.ttf cinzeldecorative/CinzelDecorative-Bold.ttf \
         'notosanssymbols/NotoSansSymbols%5Bwght%5D.ttf' notosanssymbols2/NotoSansSymbols2-Regular.ttf; do
    out="$d/$(basename "$f" | sed 's/%5B/[/; s/%5D/]/')"
    [ -s "$out" ] || curl -fsSL -o "$out" "$base/$f" || echo "failed: $f" >&2
done
fc-cache -f "$d" >/dev/null && echo "fonts in $d"
