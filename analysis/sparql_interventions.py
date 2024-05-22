from SPARQLWrapper import SPARQLWrapper, CSV
import os
from pathlib import Path
import psycopg

endpoint = os.environ.get("REMOTE_SPARQL_ENDPOINT")

sparql = SPARQLWrapper(endpoint)

sparql.setReturnFormat(CSV)

query_file = Path("analysis/interventions_pubchem.rq")
query = query_file.read_text()

sparql.setQuery(query)

intervention_names = []

with psycopg.connect("dbname=AACT-2024 user=postgres password=postgres") as conn:
    res = conn.execute("select top 1 * from ctgov.interventions")
    res.fetchall()

ret = sparql.queryAndConvert()

outfile = Path("analysis/query_out.csv")
outfile.touch(exist_ok=True)

with open(outfile, "wb") as f:
    f.write(ret)