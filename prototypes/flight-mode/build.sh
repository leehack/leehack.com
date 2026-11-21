#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/../.."
SITE_BASE=/ dart run jaspr_cli:jaspr build

cd prototypes/flight-mode
mkdir -p build
cp -R ../../build/jaspr/. build/

dart pub get
dart compile js -O2 flight.dart -o build/semantic.dart.js
dart run llamadart:web_setup --web-dir build
dart run llamadart:web_setup --web-dir build --check

model_file=build/bge-small-en-v1.5-q8_0.gguf
python3 - "${model_file##*/}" <<'PYTHON'
from pathlib import Path
import sys

page = Path('build/index.html')
html = page.read_text()
before, begin, rest = html.partition('<!-- llamadart:web_setup:begin -->')
bootstrap, end, after = rest.partition('<!-- llamadart:web_setup:end -->')
_, opening, script = bootstrap.partition('<script type="module">')
script, closing, _ = script.partition('</script>')
if not all((begin, end, opening, closing, script.strip())):
    raise ValueError('Expected a generated llamadart module bootstrap')

Path('build/finder-bridge.js').write_text(
    'export async function loadFinderBridge() {\n'
    '  delete window.__llamadartBridgeLoadError;\n'
    + script
    + '  if (!window.LlamaWebGpuBridge) {\n'
    '    throw new Error(window.__llamadartBridgeLoadError);\n'
    '  }\n'
    '  return window.LlamaWebGpuBridge;\n'
    '}\n'
)
page.write_text(before + f'<meta name="finder-model" content="{sys.argv[1]}">\n' + after)
PYTHON
model_sha=f046db1dc724cf4f6f0a0c5917e922823b73eb1d27b8f9a9c2797f7866974804
if ! printf '%s  %s\n' "$model_sha" "$model_file" | shasum -a 256 -c --status; then
  model_url=https://huggingface.co/ggml-org/bge-small-en-v1.5-Q8_0-GGUF/resolve/f2068edd9b54f2a369549ccc71f70ed273a2a801/bge-small-en-v1.5-q8_0.gguf
  curl -fL --retry 2 "$model_url" -o "$model_file.part"
  printf '%s  %s\n' "$model_sha" "$model_file.part" | shasum -a 256 -c
  mv "$model_file.part" "$model_file"
fi
