import http.server, json, socketserver, sys, threading, time

class Server(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True

class Handler(http.server.BaseHTTPRequestHandler):
    leaks = 0
    def log_message(self, *args): pass
    def send(self, value, status=200):
        data = json.dumps(value).encode()
        self.send_response(status); self.send_header('Content-Type', 'application/json'); self.end_headers()
        self.wfile.write(data)
    def do_GET(self):
        if self.path.startswith('/redirect/'):
            self.send_response(302); self.send_header('Location', '/stolen'); self.end_headers(); return
        if self.path == '/stolen': Handler.leaks += 1; self.send({'leaked': True}); return
        if self.path == '/leaks': self.send({'count': Handler.leaks}); return
        if self.headers.get('Authorization') != 'Bearer fixture-key' and self.headers.get('X-Api-Key') != 'fixture-key':
            self.send({}, 401); return
        second = 'after=' in self.path or 'after_id=' in self.path
        self.send({'data': [{'id': 'model-two' if second else 'model-one', 'display_name': 'Second' if second else 'First'}],
                   'has_more': not second, 'last_id': 'model-two' if second else 'model-one'})
    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers['Content-Length'])))
        model = body.get('model', '')
        if model == 'slow': time.sleep(4)
        self.send_response(200); self.send_header('Content-Type', 'text/event-stream'); self.end_headers()
        def event(value):
            self.wfile.write(('data: ' + json.dumps(value) + '\n\n').encode()); self.wfile.flush()
        try:
            if self.path.endswith('/responses'):
                if model == 'broken': event({'type': 'response.incomplete'}); return
                event({'type': 'response.output_text.delta', 'delta': 'hello'})
                event({'type': 'response.completed', 'response': {'output': [], 'usage': {'output_tokens': 1}}})
            elif self.path.endswith('/chat/completions'):
                event({'choices': [{'delta': {'content': 'hello'}, 'finish_reason': None}]})
                event({'choices': [{'delta': {}, 'finish_reason': 'stop'}]})
                self.wfile.write(b'data: [DONE]\n\n')
            else:
                for value in [
                    {'type': 'message_start', 'message': {'id': 'fixture', 'type': 'message', 'role': 'assistant', 'content': []}},
                    {'type': 'content_block_start', 'index': 0, 'content_block': {'type': 'text', 'text': ''}},
                    {'type': 'content_block_delta', 'index': 0, 'delta': {'type': 'text_delta', 'text': 'hello'}},
                    {'type': 'content_block_stop', 'index': 0},
                    {'type': 'message_delta', 'delta': {'stop_reason': 'end_turn'}}, {'type': 'message_stop'}]: event(value)
        except (BrokenPipeError, ConnectionResetError): pass

server = Server(('127.0.0.1', 0), Handler)
print(server.server_port, flush=True)
threading.Thread(target=server.serve_forever, daemon=True).start()
sys.stdin.read()
