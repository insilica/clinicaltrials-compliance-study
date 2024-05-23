from SPARQLWrapper import SPARQLWrapper, CSV
import os
from pathlib import Path
import psycopg

endpoint = os.environ.get("REMOTE_SPARQL_ENDPOINT")

sparql = SPARQLWrapper(endpoint)

sparql.setReturnFormat(CSV)

query_file = Path("analysis/interventions_pubchem.rq")
query = query_file.read_text()


class Interventions:
    db_conn: psycopg.Connection = None
    intervention_names: list = []

    def __init__(self):
        with psycopg.connect(
            "dbname=AACT-2024 user=postgres password=postgres"
        ) as conn:
            self.db_conn = conn
            res = conn.execute(
                "select name from ctgov.interventions where intervention_type = 'Drug'"
            )
            self.intervention_names.extend(
                (
                    name[0]
                    for name in res.fetchall()
                    if isinstance(name, tuple) and len(name) == 1
                )
            )
    
    def __del__(self):
        self.db_conn.close()

interventions = Interventions()

test_query = query_file.read_text().replace("replaceMe", f"\'{interventions.intervention_names[0]}\'")

sparql.setQuery(test_query)

ret = sparql.queryAndConvert()

outfile = Path("analysis/query_out.csv")
outfile.touch(exist_ok=True)

with open(outfile, "wb") as f:
    f.write(ret)