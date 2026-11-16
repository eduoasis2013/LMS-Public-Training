#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Comprehensive probe for the Supabase pooler endpoint that hosts this project."""
import psycopg2, urllib.request, json

ALL = ["ap-east-1","ap-southeast-1","ap-southeast-2","ap-northeast-1","ap-northeast-2","ap-south-1",
       "us-east-1","us-east-2","us-west-1","us-west-2",
       "eu-central-1","eu-west-1","eu-west-2","eu-west-3","eu-north-1","eu-south-1",
       "me-central-1","af-south-1","sa-east-1","ca-central-1","il-central-1"]
USER = "postgres.ehmkapncaoupgunzoxba"
PW = "Eduoasispublictraining"

def resolve4(host):
    try:
        with urllib.request.urlopen(f"https://dns.google/resolve?name={host}&type=A",timeout=8) as r:
            d=json.load(r)
        for a in (d.get('Answer') or []):
            if a.get('type')==1: return a.get('data')
    except Exception: pass
    return None

hosts=[]
for reg in ALL:
    hosts.append((f"aws-0-{reg}.pooler.supabase.com", reg))
hosts.append(("pooler.supabase.com","global"))

for host,label in hosts:
    ip=resolve4(host)
    if not ip:
        print(f"{label}: no A record"); continue
    for port in (6543,5432):
        cs=f"postgresql://{USER}:{PW}@{ip}:{port}/postgres?sslmode=require&host={host}"
        try:
            c=psycopg2.connect(cs, connect_timeout=10)
            cur=c.cursor(); cur.execute("SELECT current_database(), current_user"); row=cur.fetchone()
            print(f"*** {label}:{port} CONNECT_OK db={row[0]} user={row[1]}")
            cur.close(); c.close()
            print("FOUND_HOST="+host); print("FOUND_PORT="+str(port)); raise SystemExit(0)
        except SystemExit: raise
        except Exception as e:
            m=str(e).replace(PW,"<pw>")
            tag = "ENOTFOUND" if "ENOTFOUND" in m else ("auth" if "authentication" in m.lower() or "password" in m.lower() else "other")
            print(f"{label}:{port} {tag} {m[:90]}")
print("NONE_FOUND")
