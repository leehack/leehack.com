from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path


class PreviewHandler(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        build = Path(__file__).resolve().parent / "build"
        super().__init__(*args, directory=str(build), **kwargs)

    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        super().end_headers()


if __name__ == "__main__":
    address = ("127.0.0.1", 8094)
    with ThreadingHTTPServer(address, PreviewHandler) as server:
        print(f"Resource finder preview: http://{address[0]}:{address[1]}/", flush=True)
        server.serve_forever()
