#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Test connectivity to the Supabase Postgres database."""
import psycopg2, sys

DSI = "postgresql://postgres:Eduoasispublictraining@db.ehmkapncaoupgunzoxba.supabase.co:5432/postgres"

try:
    conn = psycopg2.connect(DSI, connect_timeout=20)
    conn.autocommit = True
    cur = conn.cursor()
    cur.execute("SELECT version();")
    print("VERSION:", cur.fetchone()[0][:80])
    cur.execute("SELECT current_database(), current_user;")
    print("DB/USER:", cur.fetchone())
    cur.execute("SELECT count(*) FROM information_schema.tables WHERE table_schema='public';")
    print("public tables count:", cur.fetchone()[0])
    cur.execute("SELECT current_setting('server_version')")
    print("server_version:", cur.fetchone()[0])
    cur.close(); conn.close()
    print("CONNECT_OK")
except Exception as e:
    print("CONNECT_FAIL:", type(e).__name__, e)
    sys.exit(1)
