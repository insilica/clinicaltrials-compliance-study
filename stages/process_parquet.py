import duckdb
from pathlib import Path
from itertools import islice

work_dir = Path("work")
cols = [
    "primary_completion_date",
    "study_start_date",
    "version_date",
    "overall_status",
    "enrolment_type",
    "enrolment",
    "nctid",
    "version_number",
    "status",
]
cols_ = ",".join([f'"{col}"' for col in cols])
table_list = ["work/empty.parquet", "work/NCT*.parquet"]
for f in islice(work_dir.iterdir(), 1):
    duckdb.sql(f"SELECT {cols_} FROM '{f}'")


duckdb.sql(f"""COPY 
    (SELECT {cols_} 
    FROM read_parquet({table_list}, union_by_name=true))
    TO 'work/all_study_records.parquet' (COMPRESSION ZSTD)""")
print(cols_)
