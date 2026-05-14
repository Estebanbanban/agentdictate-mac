#!/usr/bin/env python3
"""Mock OpenAI server for AgentDictate E2E smoke test."""
import http.server
import json

class Handler(http.server.BaseHTTPRequestHandler):
    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        _ = self.rfile.read(length)
        if self.path.endswith('/audio/transcriptions'):
            body = json.dumps({"text": "smoke test from mock openai"})
        elif self.path.endswith('/chat/completions'):
            body = json.dumps({"choices": [{"message": {"content": "cleaned smoke test"}}]})
        else:
            body = json.dumps({"error": "unknown endpoint"})
        data = body.encode()
        self.send_response(200)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, fmt, *args):
        # quiet stderr
        pass

if __name__ == '__main__':
    server = http.server.HTTPServer(('127.0.0.1', 18088), Handler)
    print('mock openai on http://127.0.0.1:18088', flush=True)
    server.serve_forever()
