import sqlite3
import os

db_path = 'test_bible.db'
if not os.path.exists(db_path):
    print(f"DB not found: {db_path}")
    exit(1)

conn = sqlite3.connect(db_path)
cur = conn.cursor()

cur.execute('SELECT count(*) FROM words WHERE book_number >= 10')
print(f"Words >= 10: {cur.fetchone()[0]}")

cur.execute('SELECT count(*) FROM books WHERE book_number >= 10')
print(f"Books >= 10: {cur.fetchone()[0]}")

cur.execute('SELECT count(*) FROM words WHERE book_number < 40')
print(f"Words < 40 (OT): {cur.fetchone()[0]}")

cur.execute('SELECT count(*) FROM books WHERE book_number < 40')
print(f"Books < 40 (OT): {cur.fetchone()[0]}")
