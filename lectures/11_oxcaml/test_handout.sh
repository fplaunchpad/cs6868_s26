#!/bin/sh
# Test the lecture handout with ocaml-mdx.
# Uses a wrapper to enable -extension-universe alpha for comprehensions.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
WRAP="$DIR/.mdx-wrapper"
mkdir -p "$WRAP"
cat > "$WRAP/ocaml" <<SCRIPT
#!/bin/sh
exec ocaml -extension-universe alpha "\$@"
SCRIPT
chmod +x "$WRAP/ocaml"
rm -f "$DIR/handout.md.corrected"
PATH="$WRAP:$PATH" ocaml-mdx test \
  --prelude-str='[@@@alert "-do_not_spawn_domains"]' \
  "$DIR/handout.md"
if [ -f "$DIR/handout.md.corrected" ]; then
  echo "FAIL: mdx output differs from handout. See handout.md.corrected." >&2
  diff -u "$DIR/handout.md" "$DIR/handout.md.corrected" | head -80 >&2
  exit 1
fi
echo "All mdx tests passed."
