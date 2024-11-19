#!/bin/sh

set -eu

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 parameter_key" >&2
	exit 1
fi

export BIN_NAME="$0"
export PARAM_KEY="$1"; shift

(
echo 'key,count'; # header
for i in $( ls sql/params/hlact-filter/hlact-filter-*.part.yaml | sort ); do
	script/tt-render-by-param $PARAM_KEY sql/create_cthist_hlact.sql $i \
		| duckdb -noheader -csv;
done
) \
| duckdb -csv -c "$(cat <<SQL
	SELECT
	    key,
	    count,
	    count - LAG(count) OVER (ORDER BY rowid) AS delta
	FROM (
	    SELECT
	        ROW_NUMBER() OVER () AS rowid,
	        *,
	    FROM read_csv_auto('/dev/stdin')
	)
	ORDER BY rowid ASC;
SQL
)"
