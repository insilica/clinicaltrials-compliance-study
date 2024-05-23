from dataclasses import dataclass
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


@dataclass
class SparqlRunner:
    query_template: str = query_file.read_text()
    sparql: SPARQLWrapper = SPARQLWrapper(endpoint)
    out_file = open("analysis/query_out.csv", "w")

    def make_query(self, int_list: list):
        self.out_file.write("name,compound,synonym")
        for val in int_list:
            query = self.query_template.replace("replaceMe", f"'{val}'")
            print(f"Running SPARQL query for {val}.")
            try:
                ret = self.set_and_run_query(query).decode("utf-8")
                if ret != r"\"name\",\"compound\",\"synonym\"":
                    written = self.out_file.write(ret)
                    print(f"wrote {written} bytes to {self.out_file}")
            except Exception:
                continue
        self.out_file.close()
        

    def set_and_run_query(self, query):
        self.sparql.setQuery(query)
        self.sparql.setReturnFormat(CSV)
        ret = None
        try:
            ret = self.sparql.queryAndConvert()
            return ret
        except Exception:
            raise Exception(f"Query error running {query}.")

    def process(self):
        interventions = Interventions()
        self.make_query(interventions.intervention_names)

    def __call__(self):
        self.process()


if __name__ == "__main__":
    sparql = SparqlRunner()
    print("running all SPARQL queries.")
    try:
        sparql()
    except RuntimeError as e:
        print(e)
