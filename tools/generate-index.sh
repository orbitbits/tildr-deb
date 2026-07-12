#!/usr/bin/env bash
# Maintainer: William Canin <hello.williamcanin@gmail.com>
#
# Generate index.html in each directory for file listing on GitHub Pages.
set -euo pipefail

ROOT_DIR="${1:-repo}"

if [ ! -d "$ROOT_DIR" ]; then
  echo "Directory not found: $ROOT_DIR" >&2
  exit 1
fi

human_size() {
  local bytes=$1
  if   [ "$bytes" -ge 1073741824 ]; then printf "%.1f GB" "$(echo "scale=1; $bytes/1073741824" | bc)"
  elif [ "$bytes" -ge 1048576 ];    then printf "%.1f MB" "$(echo "scale=1; $bytes/1048576" | bc)"
  elif [ "$bytes" -ge 1024 ];       then printf "%.1f KB" "$(echo "scale=1; $bytes/1024" | bc)"
  else printf "%d B" "$bytes"
  fi
}

generate_index() {
  local dir="$1"
  local title
  title=$(echo "$dir" | sed "s|${ROOT_DIR}||; s|^/|/|; s|/$||")
  [ -z "$title" ] && title="/"

  local entries=""

  # Subdirectories
  while IFS= read -r -d '' subdir; do
    local name
    name=$(basename "$subdir")
    local date
    date=$(stat -c '%y' "$subdir" 2>/dev/null | cut -d' ' -f1)
    entries+="<tr><td><a href=\"${name}/index.html\">${name}/</a></td><td>-</td><td>${date}</td></tr>\n"
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

  # Files
  while IFS= read -r -d '' file; do
    local name size date
    name=$(basename "$file")
    size=$(stat -c '%s' "$file" 2>/dev/null)
    date=$(stat -c '%y' "$file" 2>/dev/null | cut -d' ' -f1)
    entries+="<tr><td><a href=\"${name}\">${name}</a></td><td>$(human_size "$size")</td><td>${date}</td></tr>\n"
  done < <(find "$dir" -maxdepth 1 -mindepth 1 -type f -print0 | sort -z)

  cat > "${dir}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Index of ${title}</title>
<style>
  body { font-family: monospace; margin: 2rem; background: #fff; color: #333; }
  h1 { font-size: 1.2rem; border-bottom: 1px solid #ccc; padding-bottom: .5rem; }
  table { border-collapse: collapse; width: 100%; }
  td, th { text-align: left; padding: .3rem .8rem; }
  tr:nth-child(even) { background: #f6f6f6; }
  a { color: #0366d6; text-decoration: none; }
  a:hover { text-decoration: underline; }
  .footer { margin-top: 2rem; font-size: .8rem; color: #999; border-top: 1px solid #eee; padding-top: .5rem; }
</style>
</head>
<body>
<h1>Index of ${title}</h1>
<table>
<tr><th>Name</th><th>Size</th><th>Date</th></tr>
EOF

  # Parent directory link
  if [ "$dir" != "$ROOT_DIR" ]; then
    echo '<tr><td><a href="../index.html">../</a></td><td>-</td><td>-</td></tr>' >> "${dir}/index.html"
  fi

  printf "$entries" >> "${dir}/index.html"

  cat >> "${dir}/index.html" <<EOF
</table>
<div class="footer">&copy; <a href="https://orbitbits.com">OrbitBits</a></div>
</body>
</html>
EOF
}

# Generate index.html for all directories recursively (depth-first)
while IFS= read -r -d '' dir; do
  generate_index "$dir"
done < <(find "$ROOT_DIR" -type d -print0 | sort -zr)

echo "Generated index.html in $(find "$ROOT_DIR" -name index.html | wc -l) directories"
