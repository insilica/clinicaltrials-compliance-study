# Make sure that enrollment is an integer
jsonl.studies$schema1.enrollment |> class()

########

# Check phases for schema1
jsonl.studies$schema1.phase |> levels()

# Are the levels used the same in both?
( jsonl.studies$common.phase |> levels() ==
  hlact.studies$common.phase |> levels() ) |> all()

########

# Are the types used for dates the same in both?
( hlact.studies$common.primary_completion_date_imputed |> class() ==
  jsonl.studies$common.primary_completion_date_imputed |> class() )

########

# Map primary_purpose levels to each other.
data.frame(
  one = hlact.studies$common.primary_purpose  |> levels(),
  two = jsonl.studies$schema1.primary_purpose |> levels()
)

########

# What levels are used for allocation in each? Did the mapping get done
# properly?
data.frame(
  one = hlact.studies$common.allocation  |> levels(),
  two = jsonl.studies$common.allocation  |> levels(),
  thr = jsonl.studies$schema1.allocation |> levels()
)

########

# What are the levels for masking? Are they using the same levels?
c(
  zer = as.list(hlact.studies$schema0.masking  |> levels()),
  one = as.list(hlact.studies$common.masking  |> levels()),
  two = as.list(jsonl.studies$common.masking  |> levels()),
  thr = as.list(jsonl.studies$schema1.masking |> levels())
)

# Check masking by using group_by()
jsonl.studies |>
  select( schema1.nct_id, schema1.masking ) |>
  rename( nct_id = schema1.nct_id ) |>
  inner_join( # has to be in both
             hlact.studies |> rename( nct_id = schema0.nct_id ),
             by = 'nct_id' ) |>
  select( nct_id, schema1.masking, schema0.masking, common.masking ) |>
  group_by(  schema0.masking, common.masking, schema1.masking ) |>
  count() |> arrange(desc(n))

########

# Check intervention_type mapping by using group_by()
jsonl.studies |>
  mutate(itypes_str =
         map_chr(schema1.intervention_type,
                 ~ paste(sort(.x), collapse=","))) |>
  group_by( itypes_str, common.intervention_type  ) |>
  #filter( common.intervention_type == 'Device' ) |>
  count() |> arrange(desc(n)) |> print(n = 50)

########

# Get list of funding levels
c(
  one = c(hlact.studies$common.funding |> levels()),
  two = c(jsonl.studies$schema1.funding_source |> levels())
)

# Check funding via group_by()
jsonl.studies |>
	group_by( schema1.funding_source, common.funding ) |>
	count() |> arrange(desc(n)) |> print(n = 50)

########

# Check levels for overall_status
data.frame(
  one = c(hlact.studies$common.overall_status  |> levels()),
  two = c(jsonl.studies$common.overall_status  |> levels()),
  thr = c(jsonl.studies$schema1.overall_status |> levels())
)

# Check overall_status via group_by()
jsonl.studies |>
	group_by( schema1.overall_status, common.overall_status ) |>
	count() |> arrange(desc(n)) |> print(n = 50)

