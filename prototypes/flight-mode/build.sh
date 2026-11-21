#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/../.." && pwd)
prototype="$root/prototypes/flight-mode"
if (( $# > 1 )); then
  echo "Usage: $0 [built-site-directory]" >&2
  exit 1
fi

if (( $# == 1 )); then
  output=$(cd "$1" && pwd)
else
  output="$prototype/build"
  cd "$root"
  SITE_BASE=/ dart run jaspr_cli:jaspr build
  mkdir -p "$output"
  cp -R build/jaspr/. "$output/"
fi

cd "$prototype"
dart pub get
dart compile js -O2 --no-source-maps flight.dart -o "$output/semantic.dart.js"
rm -f "$output/semantic.dart.js.deps"
dart run llamadart:web_setup --web-dir "$output"
dart run llamadart:web_setup --web-dir "$output" --check
cp NOTICES.txt "$output/finder-notices.txt"

model_file="$output/bge-small-en-v1.5-q8_0.gguf"
python3 - "$output" "${model_file##*/}" <<'PYTHON'
from pathlib import Path
import re
import sys

output = Path(sys.argv[1])
page = output / 'index.html'
html = re.sub(r'<meta name="finder-model" content="[^"]+">\n', '', page.read_text())
before, begin, rest = html.partition('<!-- llamadart:web_setup:begin -->')
bootstrap, end, after = rest.partition('<!-- llamadart:web_setup:end -->')
_, opening, script = bootstrap.partition('<script type="module">')
script, closing, _ = script.partition('</script>')
if not all((begin, end, opening, closing, script.strip())):
    raise ValueError('Expected a generated llamadart module bootstrap')

(output / 'finder-bridge.js').write_text(
    'export async function loadFinderBridge() {\n'
    '  delete window.__llamadartBridgeLoadError;\n'
    + script
    + '  if (!window.LlamaWebGpuBridge) {\n'
    '    throw new Error(window.__llamadartBridgeLoadError);\n'
    '  }\n'
    '  return window.LlamaWebGpuBridge;\n'
    '}\n'
)
page.write_text(before + f'<meta name="finder-model" content="{sys.argv[2]}">\n' + after)
PYTHON
model_sha=f046db1dc724cf4f6f0a0c5917e922823b73eb1d27b8f9a9c2797f7866974804
if [[ ! -f "$model_file" ]] || ! printf '%s  %s\n' "$model_sha" "$model_file" | shasum -a 256 -c --status; then
  model_url=https://huggingface.co/ggml-org/bge-small-en-v1.5-Q8_0-GGUF/resolve/f2068edd9b54f2a369549ccc71f70ed273a2a801/bge-small-en-v1.5-q8_0.gguf
  curl -fL --retry 2 "$model_url" -o "$model_file.part"
  printf '%s  %s\n' "$model_sha" "$model_file.part" | shasum -a 256 -c
  mv "$model_file.part" "$model_file"
fi
