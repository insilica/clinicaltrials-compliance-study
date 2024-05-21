import pandas as pd
import sys
import os
from pathlib import Path
import shutil

InDirName = sys.argv[1]
OutDirName = sys.argv[2]

#create folder -> parquet split in 1 Gb
try:
    os.mkdir(OutDirName)
except OSError:
    shutil.rmtree(OutDirName)
    os.mkdir(OutDirName)

# navigate in folder and retieve only table of interest
l_files_download = os.listdir(InDirName)
for file_download in l_files_download:
    file_path = Path(file_download)
    in_file = os.path.join(InDirName, file_path)
    file_ext = file_path.suffix
    file_name = file_path.stem
    if file_ext == ".xlsx":
        xlsx = pd.ExcelFile(in_file, engine="calamine")
        l_sheet = xlsx.sheet_names
        for sheet in l_sheet:
            out_file = os.path.join(OutDirName, f"{file_path.stem}_{sheet.replace(' ', '_')}.parquet")
            df = pd.read_excel(in_file, sheet_name=sheet, dtype=str, engine="calamine")
            df.to_parquet(out_file)
    elif file_ext == ".txt":
        out_file = os.path.join(OutDirName, file_path.with_suffix(".parquet"))
        df = pd.read_csv(in_file, sep="\t", encoding='unicode_escape',
                         low_memory=False, on_bad_lines='skip')
        df.to_parquet(out_file)

print(f"csv2parquet: Converting file {InDirName}")
