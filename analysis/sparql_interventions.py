from dataclasses import dataclass, field
import json
import os
import pandas as pd
from pathlib import Path
import psycopg
from SPARQLWrapper import SPARQLWrapper, JSON


class Interventions:
    db_conn: psycopg.Connection = None
    intervention_names: list = []

    def __init__(self):
        # assumes DB is running on localhost port 5432
        with psycopg.connect(
            "dbname=AACT-2024 user=postgres password=postgres"
        ) as conn:
            self.db_conn = conn
            res = conn.execute(
                "select id, name from ctgov.interventions where intervention_type = 'Drug'"
            )
            self.intervention_names.extend(
                (
                    {"name": name, "id": id}
                    for (id, name) in res.fetchall()
                )
            )

    def __del__(self):
        self.db_conn.close()


@dataclass
class SparqlRunner:
    endpoint = os.environ.get("REMOTE_SPARQL_ENDPOINT")
    query_file = Path("analysis/interventions_pubchem.rq")
    query_template: str = query_file.read_text()
    sparql: SPARQLWrapper = SPARQLWrapper(endpoint, returnFormat=JSON)
    out_file = open("analysis/query_out.csv", "w")
    df_list: list = field(default_factory=lambda: [])

    def format_query(self):
        interventions = Interventions()
        self.make_query(interventions.intervention_names)
        

    def make_query(self, int_list: list[dict]):
        self.out_file.write("name,compound,synonym")
        for val in int_list:
            query = self.query_template.replace("replaceMe", f"'{val['name']}'")
            print(f"Running SPARQL query for {val}.")
            try:
                ret = self.set_and_run_query(query)
                if ret is not None:
                    ret["id"] |= val["id"]
                    self.df_list.append(ret)
                    written = self.out_file.write(json.dumps(ret))
                    print(f"wrote {written} bytes to {self.out_file}")
            except Exception:
                continue
        self.out_file.close()
        

    def set_and_run_query(self, query):
        self.sparql.setQuery(query)
        ret = None
        try:
            ret = self.sparql.queryAndConvert()
            return ret
        except Exception:
            raise Exception(f"Query error running {query}.")

    def process(self):
        df = pd.DataFrame.from_records(self.df_list)
        df.to_parquet("analysis/interventions.parquet")

    def __call__(self):
        print("running all SPARQL queries.")
        self.process()


if __name__ == "__main__":
    sparql = SparqlRunner()
    try:
        sparql()
    except RuntimeError as e:
        print(e)
