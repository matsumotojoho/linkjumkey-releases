import http.client
import json
import sqlite3
import tempfile
import threading
import unittest
from contextlib import closing
from pathlib import Path
from unittest.mock import patch

from demo_adapter import CUSTOMERS, create_server, initialize_database, search_database, validate_query


class DatabaseTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.db = Path(self.temp.name) / 'synthetic.sqlite3'
        initialize_database(self.db)

    def tearDown(self):
        self.temp.cleanup()

    def test_japanese_and_halfwidth(self):
        self.assertEqual(['DEMO-001', 'DEMO-002'], [r['CustomerId'] for r in search_database(self.db, 'ｻｸﾗ')])
        self.assertEqual('DEMO-008', search_database(self.db, 'ｶﾞﾗｽ')[0]['CustomerId'])

    def test_quotes_and_sql_metacharacters(self):
        self.assertEqual('DEMO-003', search_database(self.db, "O'Reilly & Sons")[0]['CustomerId'])
        self.assertEqual('DEMO-004', search_database(self.db, '%_')[0]['CustomerId'])
        self.assertEqual([], search_database(self.db, "' OR 1=1; DROP TABLE customers; --"))
        self.assertEqual(len(CUSTOMERS), len(search_database(self.db, '架空')))

    def test_newline_is_one_string(self):
        self.assertEqual('DEMO-007', search_database(self.db, '\n 第一行\n第二行 \n')[0]['CustomerId'])

    def test_input_limits(self):
        for value in ('', ' \r\n ', 'a\x00b', 'a' * 8193, '😀' * 4097, None):
            with self.subTest(value_type=type(value).__name__):
                with self.assertRaises(ValueError):
                    validate_query(value)
        self.assertEqual('😀' * 4096, validate_query('😀' * 4096))

    def test_refuses_unknown_database(self):
        other = Path(self.temp.name) / 'existing.sqlite3'
        with closing(sqlite3.connect(other)) as conn, conn:
            conn.execute('CREATE TABLE enterprise_customers (name TEXT)')
        with self.assertRaises(ValueError):
            initialize_database(other)

    def test_connections_release_handles_on_success_and_failure(self):
        # Keep strong references so garbage collection cannot hide a leaked
        # connection on platforms that allow deleting an open database file.
        connections = []
        connect = sqlite3.connect

        def tracked_connect(*args, **kwargs):
            conn = connect(*args, **kwargs)
            connections.append(conn)
            return conn

        fresh = Path(self.temp.name) / 'fresh.sqlite3'
        invalid = Path(self.temp.name) / 'invalid.sqlite3'
        with closing(connect(invalid)) as conn, conn:
            conn.execute('CREATE TABLE unrelated (name TEXT)')
        try:
            with patch('demo_adapter.sqlite3.connect', side_effect=tracked_connect):
                initialize_database(fresh)
                initialize_database(fresh)  # Existing demo marker returns early.
                self.assertEqual(2, len(search_database(fresh, 'ｻｸﾗ')))
                with self.assertRaises(ValueError):
                    initialize_database(invalid)
                with self.assertRaises(sqlite3.OperationalError):
                    search_database(invalid, '架空')
            self.assertEqual(5, len(connections))
            for index, conn in enumerate(connections):
                with self.subTest(connection=index):
                    with self.assertRaises(sqlite3.ProgrammingError):
                        conn.execute('SELECT 1')
            # Windows must allow cleanup immediately, while references remain.
            fresh.unlink()
            invalid.unlink()
        finally:
            for conn in connections:
                conn.close()


class HttpTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.server = create_server(Path(self.temp.name), 'test-only-token-12345', 0)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join()
        self.temp.cleanup()

    def request(self, method, path, body=None, auth=True, **extra):
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port)
        headers = {'Content-Type': 'application/json; charset=utf-8', **extra}
        if auth:
            headers['Authorization'] = 'Bearer test-only-token-12345'
        if isinstance(body, dict):
            body = json.dumps(body, ensure_ascii=False).encode('utf-8')
        conn.request(method, path, body=body, headers=headers)
        response = conn.getresponse()
        status, payload = response.status, response.read()
        conn.close()
        return status, payload

    def test_actual_sql_over_http(self):
        status, data = self.request('POST', '/customers/search', {'query': 'ｻｸﾗ'})
        self.assertEqual(200, status)
        self.assertEqual(2, json.loads(data)['count'])

    def test_auth_route_and_origin(self):
        self.assertEqual(401, self.request('POST', '/customers/search', {'query': '架空'}, auth=False)[0])
        self.assertEqual(403, self.request('POST', '/customers/search', {'query': '架空'}, Origin='https://example.invalid')[0])
        self.assertEqual(404, self.request('POST', '/customers/search/', {'query': '架空'})[0])

    def test_invalid_payload(self):
        for body in ({'query': ''}, {'query': '\x00'}, {'query': 'a', 'extra': True}, {'query': []}, b'null', b'not-json'):
            self.assertEqual(400, self.request('POST', '/customers/search', body)[0])

    def test_reports_and_traversal(self):
        name = '0' * 32 + '.html'
        (Path(self.temp.name) / 'reports' / name).write_text('<p>合成データ</p>', encoding='utf-8')
        self.assertEqual((200, '<p>合成データ</p>'.encode()), self.request('GET', '/reports/' + name))
        self.assertEqual(404, self.request('GET', '/reports/../synthetic-customers.sqlite3')[0])
        self.assertEqual(404, self.request('GET', '/reports/%2e%2e/synthetic-customers.sqlite3')[0])


if __name__ == '__main__':
    unittest.main(verbosity=2)
