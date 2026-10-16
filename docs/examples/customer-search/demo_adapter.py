#!/usr/bin/env python3
"""Synthetic SQLite customer search and static report adapter. No third-party packages."""
import argparse
import hmac
import json
import re
import secrets
import sqlite3
import sys
import unicodedata
from contextlib import closing
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

FIELDS = ("CustomerId", "CustomerName", "Kana", "Prefecture", "Contact", "Notes")
CUSTOMERS = [
    ("DEMO-001", "架空さくら工業", "サクラコウギョウ", "東京都", "架空担当A", "機械部品 / synthetic only"),
    ("DEMO-002", "架空さくら物流", "ｻｸﾗﾌﾞﾂﾘｭｳ", "大阪府", "架空担当B", "配送 / synthetic only"),
    ("DEMO-003", "架空 O'Reilly & Sons", "オライリー", "神奈川県", "架空担当C", "引用符 \" と & を保持"),
    ("DEMO-004", "架空100%_商事", "ヒャクパーセント", "愛知県", "架空担当D", "SQLの%と_も文字として検索"),
    ("DEMO-005", "=HYPERLINK(\"https://example.invalid\",\"架空\")", "スプレッドシート", "福岡県", "+123456", "CSV数式対策の合成データ"),
    ("DEMO-006", "架空 <script>alert(1)</script>", "エスケープ", "北海道", "架空担当F", "HTMLエスケープの合成データ"),
    ("DEMO-007", "架空改行テスト", "カイギョウ", "京都府", "架空担当G", "第一行\n第二行"),
    ("DEMO-008", "架空ガラス工房", "ガラスコウボウ", "山口県", "架空担当H", "濁点・半角カナの合成データ"),
]


def normalize(value):
    return unicodedata.normalize("NFKC", value).casefold()


def validate_query(value):
    if not isinstance(value, str):
        raise ValueError("query must be a string")
    value = value.strip()
    if not value:
        raise ValueError("query must not be empty")
    if "\0" in value or len(value.encode("utf-16-le")) // 2 > 8192:
        raise ValueError("query contains NUL or exceeds 8192 UTF-16 code units")
    return value


def initialize_database(path):
    # Fail closed on an existing non-demo database; never open a supplied enterprise DB.
    # sqlite3's transaction context commits/rolls back but does not close the
    # connection. Close deterministically so Windows releases the database file.
    with closing(sqlite3.connect(path)) as conn, conn:
        existing = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
        if existing:
            try:
                marker = conn.execute("SELECT value FROM demo_metadata WHERE name='kind'").fetchone()
            except sqlite3.Error as exc:
                raise ValueError("Refusing an existing database without the demo marker") from exc
            if marker != ("linkjumkey-synthetic-customers-v1",):
                raise ValueError("Refusing a non-demo database")
            return
        conn.execute("CREATE TABLE demo_metadata (name TEXT PRIMARY KEY, value TEXT NOT NULL)")
        conn.execute("INSERT INTO demo_metadata VALUES (?, ?)", ("kind", "linkjumkey-synthetic-customers-v1"))
        conn.execute("CREATE TABLE customers (CustomerId TEXT PRIMARY KEY, CustomerName TEXT, Kana TEXT, Prefecture TEXT, Contact TEXT, Notes TEXT)")
        conn.executemany("INSERT INTO customers VALUES (?, ?, ?, ?, ?, ?)", CUSTOMERS)


def search_database(path, query):
    query = validate_query(query)
    with closing(sqlite3.connect(path)) as conn:
        conn.row_factory = sqlite3.Row
        conn.create_function("normalize_text", 1, normalize)
        # Parameter binding is intentional; '%' and '_' are literal, because this is instr(), not LIKE.
        rows = conn.execute(
            "SELECT CustomerId, CustomerName, Kana, Prefecture, Contact, Notes FROM customers "
            "WHERE instr(normalize_text(CustomerId || char(10) || CustomerName || char(10) || Kana || char(10) || "
            "Prefecture || char(10) || Contact || char(10) || Notes), normalize_text(?)) > 0 ORDER BY CustomerId",
            (query,),
        ).fetchall()
        return [dict(row) for row in rows]


def create_server(data_dir, token, port):
    data_dir = Path(data_dir).resolve()
    data_dir.mkdir(parents=True, exist_ok=True)
    report_dir = data_dir / "reports"
    report_dir.mkdir(exist_ok=True)
    database = data_dir / "synthetic-customers.sqlite3"
    initialize_database(database)

    class Handler(BaseHTTPRequestHandler):
        server_version = "SyntheticCustomerDemo/1.0"

        def log_message(self, format, *args):
            # Do not log customer queries, credentials, request paths or request bodies.
            return

        def send_content(self, status, content, content_type):
            self.send_response(status)
            self.send_header("Content-Type", content_type)
            self.send_header("Content-Length", str(len(content)))
            self.send_header("Cache-Control", "no-store")
            self.send_header("X-Content-Type-Options", "nosniff")
            self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; frame-ancestors 'none'")
            self.end_headers()
            self.wfile.write(content)

        def json_response(self, status, data):
            self.send_content(status, json.dumps(data, ensure_ascii=False).encode("utf-8"), "application/json; charset=utf-8")

        def permitted_origin(self):
            # Browser pages cannot use this as a cross-origin write/search API.
            return not self.headers.get("Origin")

        def do_GET(self):
            if not self.permitted_origin():
                return self.json_response(403, {"ok": False, "error": "Origin not accepted"})
            if self.path == "/health":
                return self.json_response(200, {"ok": True, "demo": True})
            if re.fullmatch(r"/reports/[0-9a-f]{32}\.(html|csv)", self.path):
                path = report_dir / self.path.rsplit("/", 1)[1]
                if path.is_file() and not path.is_symlink():
                    mime = "text/html; charset=utf-8" if path.suffix == ".html" else "text/csv; charset=utf-8"
                    return self.send_content(200, path.read_bytes(), mime)
            self.json_response(404, {"ok": False, "error": "not found"})

        def do_POST(self):
            if not self.permitted_origin():
                return self.json_response(403, {"ok": False, "error": "Origin not accepted"})
            if self.path != "/customers/search":
                return self.json_response(404, {"ok": False, "error": "not found"})
            if not hmac.compare_digest(self.headers.get("Authorization", ""), "Bearer " + token):
                return self.json_response(401, {"ok": False, "error": "unauthorized"})
            if self.headers.get("Content-Type", "").split(";", 1)[0].strip().lower() != "application/json":
                return self.json_response(415, {"ok": False, "error": "application/json required"})
            try:
                length = int(self.headers.get("Content-Length", "0"))
                if not 1 <= length <= 131072:
                    raise ValueError("invalid body length")
                self.connection.settimeout(10)
                payload = json.loads(self.rfile.read(length).decode("utf-8"))
                if not isinstance(payload, dict) or set(payload) != {"query"}:
                    raise ValueError("body must have exactly one query field")
                rows = search_database(database, payload["query"])
                self.json_response(200, {"ok": True, "count": len(rows), "rows": rows, "syntheticData": True})
            except (ValueError, UnicodeError, TimeoutError):
                self.json_response(400, {"ok": False, "error": "invalid query or request"})
            except sqlite3.Error:
                self.json_response(500, {"ok": False, "error": "demo database error"})

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--data-dir", type=Path, default=Path(__file__).parent / "demo-data")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--token-file", type=Path, help="Demo-only token file. Created if absent; never use a LinkJumkey token here.")
    args = parser.parse_args()
    args.data_dir.mkdir(parents=True, exist_ok=True)
    token_file = args.token_file or args.data_dir / "demo-api-token.txt"
    if token_file.exists():
        token = token_file.read_text(encoding="utf-8").strip()
    else:
        token = secrets.token_urlsafe(32)
        token_file.write_text(token, encoding="utf-8")
        try:
            token_file.chmod(0o600)
        except OSError:
            pass
    if not re.fullmatch(r"[A-Za-z0-9_-]{16,128}", token):
        parser.error("token file must contain a 16-128 character demo token")
    server = create_server(args.data_dir, token, args.port)
    print("Synthetic SQLite adapter: http://127.0.0.1:" + str(server.server_port), flush=True)
    print("Demo token file: " + str(token_file.resolve()), flush=True)
    print("Reports directory: " + str((args.data_dir / "reports").resolve()), flush=True)
    print("Ctrl+C to stop. All customer records are synthetic.", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
