library(arrow)
library(dplyr)
library(cthist)

nctid <- 'NCT00000125'

versions <- clinicaltrials_gov_download(nctid) |>
	mutate(across(c(
			version_number,
			total_versions,
			enrolment
		), as.integer))

arrow::write_parquet(versions, paste0(nctid, '.parquet') )
