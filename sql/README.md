# Templating for SQL parameterization

The SQL files
  - `sql/create_cthist_all.sql`
  - `sql/create_cthist_hlact.sql`
are simultaneously valid SQL and valid templates
(for [Template Toolkit](https://template-toolkit.org/)).
This is by setting the tags using the `[% TAGS %]` directive:

```sql
-- [% TAGS \[\% \%\] --%% %]
--%% ## See § Templating… in `sql/README.md`.
```

and then using only outline mode

```sql
--%% DIRECTIVE
```

throughout the SQL file. This allows the SQL to continue to be developed as
usual without changing workflows.

To render, use a command such as:

```shell

env SQL="sql/create_cthist_hlact.sql" DATA="param/stanford.2019-2023.json" \
  sh -c 'tt-render --data=$DATA $SQL'

```
and to debug, use

```shell

# DEBUG
env SQL="sql/create_cthist_hlact.sql" DATA="param/stanford.2019-2023.json" \
  bash -c 'diff -u2 $SQL <( tt-render --data=$DATA $SQL )'
  # | diff-highlight | colordiff

```
