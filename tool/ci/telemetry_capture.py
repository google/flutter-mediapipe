"""Records Google's usage-logging uploads on a CI runner, then forwards them.

The runner resolves play.googleapis.com to this process and trusts its
certificate authority, so each upload arrives here in the clear. Every request
is saved, sent on unchanged to Google's real address, and answered with
Google's own reply: nothing is blocked.

  certs DIR          write a CA (ca.cer) and a play.googleapis.com certificate
  serve DIR REAL_IP  listen on port 443, record and forward each request
  report DIR         print every recorded upload, decoded; fail if none
"""

import datetime
import gzip
import http.client
import http.server
import json
import socket
import ssl
import sys
import threading
from pathlib import Path

HOST = 'play.googleapis.com'


def certs(out):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

    out.mkdir(parents=True, exist_ok=True)
    now = datetime.datetime.now(datetime.timezone.utc)
    ca_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    ca_name = x509.Name([x509.NameAttribute(
        NameOID.COMMON_NAME, 'mediapipe_flutter CI usage-log recorder')])
    ca = (x509.CertificateBuilder()
          .subject_name(ca_name).issuer_name(ca_name)
          .public_key(ca_key.public_key())
          .serial_number(x509.random_serial_number())
          .not_valid_before(now - datetime.timedelta(days=1))
          .not_valid_after(now + datetime.timedelta(days=2))
          .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
          .add_extension(x509.KeyUsage(
              digital_signature=True, content_commitment=False,
              key_encipherment=False, data_encipherment=False,
              key_agreement=False, key_cert_sign=True, crl_sign=True,
              encipher_only=False, decipher_only=False), critical=True)
          .add_extension(x509.SubjectKeyIdentifier.from_public_key(
              ca_key.public_key()), critical=False)
          .sign(ca_key, hashes.SHA256()))
    key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    leaf = (x509.CertificateBuilder()
            .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, HOST)]))
            .issuer_name(ca_name)
            .public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - datetime.timedelta(days=1))
            .not_valid_after(now + datetime.timedelta(days=2))
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(HOST)]), critical=False)
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
            .add_extension(x509.KeyUsage(
                digital_signature=True, content_commitment=False,
                key_encipherment=True, data_encipherment=False,
                key_agreement=False, key_cert_sign=False, crl_sign=False,
                encipher_only=False, decipher_only=False), critical=True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]),
                           critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(
                ca_key.public_key()), critical=False)
            .sign(ca_key, hashes.SHA256()))
    (out / 'ca.cer').write_bytes(ca.public_bytes(serialization.Encoding.DER))
    (out / 'server.pem').write_bytes(
        leaf.public_bytes(serialization.Encoding.PEM)
        + ca.public_bytes(serialization.Encoding.PEM))
    (out / 'server.key').write_bytes(key.private_bytes(
        serialization.Encoding.PEM, serialization.PrivateFormat.TraditionalOpenSSL,
        serialization.NoEncryption()))
    print(f'Wrote {out / "ca.cer"} and the {HOST} certificate')


def serve(out, real_ip):
    lock = threading.Lock()
    count = [0]
    log = out / 'requests.jsonl'
    upstream = ssl.create_default_context()

    def forward(method, path, headers, body):
        raw = socket.create_connection((real_ip, 443), timeout=60)
        conn = http.client.HTTPSConnection(HOST, 443, timeout=60)
        conn.sock = upstream.wrap_socket(raw, server_hostname=HOST)
        try:
            conn.request(method, path, body=body, headers=headers)
            response = conn.getresponse()
            return response.status, response.getheaders(), response.read()
        finally:
            conn.close()

    class Handler(http.server.BaseHTTPRequestHandler):
        protocol_version = 'HTTP/1.1'

        def log_message(self, *args):
            pass

        def read_body(self):
            if self.headers.get('Transfer-Encoding', '').lower() == 'chunked':
                body = b''
                while True:
                    size = int(self.rfile.readline().split(b';')[0], 16)
                    if size == 0:
                        self.rfile.readline()
                        return body
                    body += self.rfile.read(size)
                    self.rfile.readline()
            return self.rfile.read(int(self.headers.get('Content-Length') or 0))

        def handle_any(self):
            body = self.read_body()
            if self.path == '/__recorder_ping':
                self.reply(200, [('Content-Type', 'text/plain')], b'recorder')
                return
            with lock:
                index = count[0]
                count[0] += 1
            (out / f'body_{index}.bin').write_bytes(body)
            headers = {k: v for k, v in self.headers.items()
                       if k.lower() not in ('host', 'content-length', 'connection',
                                            'transfer-encoding')}
            headers['Host'] = HOST
            record = {'index': index, 'time': datetime.datetime.now().isoformat(),
                      'method': self.command, 'path': self.path,
                      'headers': dict(self.headers.items()), 'body_bytes': len(body)}
            try:
                status, reply_headers, reply = forward(self.command, self.path, headers, body)
                record['google_status'] = status
                keep = [(k, v) for k, v in reply_headers
                        if k.lower() in ('content-type', 'content-encoding')]
            except Exception as error:  # Report it, and still answer the client.
                record['forward_error'] = repr(error)
                status, keep, reply = 200, [], b''
            with lock, log.open('a', encoding='utf-8') as f:
                f.write(json.dumps(record) + '\n')
            self.reply(status, keep, reply)

        def reply(self, status, headers, body):
            self.send_response(status)
            for k, v in headers:
                self.send_header(k, v)
            self.send_header('Content-Length', str(len(body)))
            self.end_headers()
            self.wfile.write(body)

        do_POST = do_GET = do_PUT = handle_any

    class Server(http.server.ThreadingHTTPServer):
        address_family = socket.AF_INET6
        daemon_threads = True

        def server_bind(self):
            self.socket.setsockopt(socket.IPPROTO_IPV6, socket.IPV6_V6ONLY, 0)
            super().server_bind()

        def get_request(self):
            try:
                return super().get_request()
            except OSError as error:
                with lock, (out / 'tls_errors.txt').open('a', encoding='utf-8') as f:
                    f.write(f'{datetime.datetime.now().isoformat()} {error!r}\n')
                raise

    out.mkdir(parents=True, exist_ok=True)
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.load_cert_chain(out / 'server.pem', out / 'server.key')
    server = Server(('::', 443), Handler)
    server.socket = context.wrap_socket(server.socket, server_side=True)
    print(f'Recording {HOST} on port 443, forwarding to {real_ip}', flush=True)
    server.serve_forever()


def varint(data, i):
    result = shift = 0
    while True:
        byte = data[i]
        i += 1
        result |= (byte & 0x7f) << shift
        shift += 7
        if not byte & 0x80:
            return result, i


def fields(data):
    """Parses a protobuf message into (field, value) pairs; nested messages
    stay bytes."""
    i, out = 0, []
    while i < len(data):
        key, i = varint(data, i)
        field, wire = key >> 3, key & 7
        if wire == 0:
            value, i = varint(data, i)
        elif wire == 1:
            value, i = int.from_bytes(data[i:i + 8], 'little'), i + 8
        elif wire == 5:
            value, i = int.from_bytes(data[i:i + 4], 'little'), i + 4
        elif wire == 2:
            size, i = varint(data, i)
            value, i = data[i:i + size], i + size
        else:
            raise ValueError(f'wire type {wire}')
        if field == 0 or i > len(data):
            raise ValueError('not a message')
        out.append((field, value))
    return out


def first(pairs, field, default=None):
    return next((v for f, v in pairs if f == field), default)


def show(data, depth=0):
    lines = []
    for field, value in fields(data):
        pad = '  ' * depth
        if isinstance(value, bytes):
            try:
                if value and not all(32 <= c < 127 for c in value):
                    nested = show(value, depth + 1)
                    lines += [f'{pad}{field}: {{', *nested, f'{pad}}}']
                    continue
            except (ValueError, IndexError):
                pass
            lines.append(f'{pad}{field}: {value.decode("utf-8", "replace")!r}')
        else:
            lines.append(f'{pad}{field}: {value}')
    return lines


ENVIRONMENTS = {0: 'UNKNOWN', 1: 'ANDROID', 2: 'IOS', 3: 'PYTHON', 4: 'WEB', 5: 'FLUTTER'}
EVENTS = {0: 'session start', 1: 'invocation report', 2: 'session end'}


def report(out):
    log = out / 'requests.jsonl'
    records = [json.loads(line) for line in log.read_text(encoding='utf-8').splitlines()] \
        if log.exists() else []
    for record in records:
        headers = {k.lower(): v for k, v in record['headers'].items()}
        print(f"\n#{record['index']} {record['method']} https://{HOST}{record['path']} "
              f"{record['body_bytes']} bytes, User-Agent {headers.get('user-agent')!r}, "
              f"Google answered {record.get('google_status', record.get('forward_error'))}")
        body = (out / f"body_{record['index']}.bin").read_bytes()
        if headers.get('content-encoding', '').lower() == 'gzip':
            body = gzip.decompress(body)
        try:
            top = fields(body)
            print(f'   log source {first(top, 2)}')
            for field, event in top:
                if field != 3:
                    continue
                inner = fields(first(fields(event), 6, b''))
                host = fields(first(inner, 1, b''))
                task = fields(first(inner, 2, b''))
                environment = first(host, 6, 0)
                version = first(host, 5, b'')
                print(f'   {EVENTS.get(first(task, 2, 0), first(task, 2, 0)):17} '
                      f'task {first(task, 1)}, environment {environment} '
                      f'({ENVIRONMENTS.get(environment, "?")}), OS {first(host, 1, 0)}, '
                      f'host_version {version.decode("utf-8", "replace")!r}')
            (out / f"body_{record['index']}.decoded.txt").write_text(
                '\n'.join(show(body)) + '\n', encoding='utf-8')
        except (ValueError, IndexError, TypeError) as error:
            print(f'   not decoded: {error!r}')
    errors = out / 'tls_errors.txt'
    if errors.exists():
        print('\nTLS handshake errors:\n' + errors.read_text(encoding='utf-8'))
    print(f'\n{len(records)} uploads recorded')
    if not records:
        sys.exit(1)


if __name__ == '__main__':
    command, folder = sys.argv[1], Path(sys.argv[2])
    if command == 'certs':
        certs(folder)
    elif command == 'serve':
        serve(folder, sys.argv[3])
    elif command == 'report':
        report(folder)
    else:
        sys.exit(__doc__)
