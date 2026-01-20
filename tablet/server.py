#!/usr/bin/env python3
import json
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 3000
HOST = '0.0.0.0'

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/songs':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            # Serve songs.json
            with open('songs.json', 'rb') as f:
                self.wfile.write(f.read())
        elif self.path == '/next':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"cmd":"next"}).encode())
        elif self.path == '/prev':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"cmd":"prev"}).encode())
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == '__main__':
    server = HTTPServer((HOST, PORT), Handler)
    print(f'🚀 Tablet server running on http://{HOST}:{PORT}')
    server.serve_forever()
