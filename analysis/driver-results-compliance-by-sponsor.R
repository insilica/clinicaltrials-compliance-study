# if(!sys.nframe()) { source('analysis/driver-results-compliance-by-sponsor.R') }
if (!require("pacman")) install.packages("pacman")
library(pacman)
pacman::p_load( logger, readr, ggrepel, openxlsx ) # nolint

source('analysis/ctgov.R')

params <- window.params.read()

output.path.base <- 'brick/post-rule-to-20240430-by_sponsor'
fs::dir_create(output.path.base)

agg.window.postrule <- windows.rdata.read('brick/post-rule-to-20240430_processed')

( agg.trials.by_sponsor <-
  agg.window.postrule[[1]]$hlact.studies
  |> mutate(
    # Which type of intervalue to use for the `dateproc.results_reported.within_inc()`
    # computation below:
    cr.interval_to_results_default = cr.interval_to_results_with_extensions_no_censor,
    # - 12 months or
    cr.results_reported_12mo_with_extensions =
      dateproc.results_reported.within_inc(pick(everything()), months(12)),
  )
  |> group_by(schema1.lead_sponsor_funding_source, schema1.lead_sponsor_name)
  |> summarize(
    rr.with_extensions = mean(cr.results_reported_12mo_with_extensions),
    rr.no_extensions   = mean(cr.results_reported_12mo),
    ncts.compliant    = list(schema1.nct_id[cr.results_reported_12mo_with_extensions == TRUE]),
    ncts.noncompliant = list(schema1.nct_id[cr.results_reported_12mo_with_extensions == FALSE]),
    n.total   = n(),
    n.success = sapply(ncts.compliant, length),
    n.failure = sapply(ncts.noncompliant, length)
  )
 |> mutate(
   # Use Wilson score interval from binom.test
   wilson.ci = map2(n.success, n.total, function(succ, total) {
     test <- binom.test(succ, total)
     test$conf.int
   }),
   wilson.conf.low  = map_dbl(wilson.ci, `[`, 1),
   wilson.conf.high = map_dbl(wilson.ci, `[`, 2)
 )
 |> select(!wilson.ci)
 |> select(
   # Move NCT columns to end
   !c(starts_with("ncts.")),
   starts_with("ncts.")
 )
 |> arrange(-wilson.conf.low, -n.total)
)

agg.trials.by_sponsor |>
  write_parquet(fs::path(output.path.base, "sponsor_compliance_summary.parquet"))


tab.agg.trials.by_sponsor <-
  agg.trials.by_sponsor |>
    mutate(
      ncts.compliant    = sapply(ncts.compliant, paste, collapse = "|"),
      ncts.noncompliant = sapply(ncts.noncompliant, paste, collapse = "|")
    )

tab.agg.trials.by_sponsor |>
  write_csv(fs::path(output.path.base, "sponsor_compliance_summary.csv"))

################################################################################
p <- agg.trials.by_sponsor |>
  mutate(
      wilson_group = factor(cut(wilson.conf.low,
                              breaks = seq(0, 1, by=0.1),
                              labels = sprintf("%.1f-%.1f", seq(0, 0.9, by=0.1), seq(0.1, 1, by=0.1)),
                              include.lowest = TRUE))
  ) |>
  ggplot(aes(x = n.total, y = n.success)) +
  geom_abline(slope = 1, linetype = "dashed", color = "gray50") +
  geom_point(aes(
    shape = schema1.lead_sponsor_funding_source,
    color = wilson_group
  ), size = 3) +
  geom_text_repel(aes(
    label = schema1.lead_sponsor_name,
    color = wilson_group
  ),
    #data = . %>% filter(n.total > quantile(n.total, 0.9)),
    data = . %>% filter( wilson.conf.low > 0 & (wilson.conf.low < 0.25 | wilson.conf.low > 0.75)),
    #size = 3,
    size = 1.5,  # smaller text size
    max.overlaps = 20
  ) +
  #scale_shape_manual(values = c(15, 16, 17, 18, 19, 20, 21, 22, 23, 24)) +  # Extended shape list
  #scale_shape_manual(values = c(2, , 17, 18, 19, 20, 21, 22, 23, 24)) +  # Extended shape list
  #scale_color_viridis_d() +
  scale_x_log10() +
  scale_y_log10() +
  labs(
    x = "Total Trials (log scale)",
    y = "Compliant Trials (log scale)",
    shape = "Funding Source",
    color = "Wilson LCB Group"
  ) +
  theme_minimal()
ggsave(fs::path(output.path.base, 'sponsor_compliance_scatter.png'),
       plot = p, width = 12, height = 8, dpi = 300)


################################################################################
# Analysis definitions
# nolint start: line_length_linter.
analyses <- list(
  list(
    name = "summary",
    description = "Complete dataset showing key compliance metrics and confidence intervals, ordered by confidence interval lower bound and total trials",
    filter = quote(TRUE), # Include all data
    arrange = list(quote(desc(wilson.conf.low)), quote(desc(n.total)))
  ),
  list(
    name = "perfect_compliance",
    description = "Sponsors with 100% compliance rate (rr.with_extensions = 1), ordered by confidence interval lower bound and total trials",
    filter = quote(rr.with_extensions == 1),
    arrange = list(quote(desc(wilson.conf.low)), quote(desc(n.total)))
  ),
  list(
    name = "high_compliance",
    description = "Sponsors with either perfect compliance or statistically confident high compliance (>50%), ordered by confidence level and total trials",
    filter = quote(wilson.conf.low > .50 | rr.with_extensions == 1),
    arrange = list(quote(desc(wilson.conf.low)), quote(desc(n.total)))
  ),
  list(
    name = "low_compliance",
    description = "Sponsors with statistically confident low compliance (<10%) but some compliance, ordered by compliance rate and total trials",
    filter = quote(wilson.conf.low < .10 & rr.with_extensions != 0),
    arrange = list(quote(desc(wilson.conf.low)), quote(desc(n.total)))
  ),
  list(
    name = "zero_compliance",
    description = "Sponsors with zero compliance (rr.with_extensions = 0), ordered by total trials",
    filter = quote(rr.with_extensions == 0),
    arrange = list(quote(desc(wilson.conf.low)), quote(desc(n.total)))
  )
)
# nolint end

# Funding source filters
funding_sources <- c("ALL" = NA, "INDUSTRY" = "INDUSTRY", "OTHER" = "OTHER")

export_sponsor_analysis <- function(data, output_file) {
  wb <- createWorkbook()

  # Create styles
  header_style <- createStyle(
    fontSize = 11,
    textDecoration = "bold",
    wrapText = TRUE,
    border = "Bottom",
    borderColour = "gray70",
    fgFill = "#F0F0F0"
  )

  row_even_style <- createStyle(fgFill = "#F8F8F8")
  row_odd_style <- createStyle(fgFill = "#FFFFFF")
  bold_header_style <- createStyle(textDecoration = "bold")

  # For each funding source
  for (fs_name in names(funding_sources)) {
    fs_value <- funding_sources[[fs_name]]

    # Filter data if funding source specified
    current_data <- if (is.na(fs_value)) {
      data
    } else {
      data %>% filter(schema1.lead_sponsor_funding_source == fs_value)
    }

    # For each analysis (including summary)
    for (analysis in analyses) {
      # Create tab name
      tab_name <- if (fs_name == "ALL") {
        analysis$name
      } else {
        paste(fs_name, analysis$name, sep="_")
      }

      # Filter and arrange data according to analysis definition
      result <- current_data %>%
        filter(!!analysis$filter) %>%
        arrange(!!!analysis$arrange)

      # Add worksheet
      addWorksheet(wb, tab_name)

      # Create description text
      description <- paste(
        "ANALYSIS DESCRIPTION:",
        analysis$description,
        if (!is.na(fs_value)) paste0("Funding Source: ", fs_value) else "",
        sep = "\n"
      )

      # Write description with formatting
      writeData(wb, tab_name, description, startRow = 1, startCol = 1)
      addStyle(wb, tab_name, header_style, rows = 1:2, cols = 1)
      setRowHeights(wb, tab_name, rows = 1:2, heights = 40)

      # For summary tabs, select and rename columns
      if (analysis$name == "summary") {
        result <- result %>%
          select(
            schema1.lead_sponsor_funding_source,
            schema1.lead_sponsor_name,
            "Compliance Rate" = rr.with_extensions,
            n.total,
            n.success,
            n.failure,
            "Wilson score lower bound" = wilson.conf.low
          )
      }

      # Write data starting after description
      writeData(wb, tab_name, result, startRow = 4)

      # Apply bold headers and alternating colors
      addStyle(wb, tab_name, bold_header_style, rows = 4, cols = 1:ncol(result))
      rows <- 5:(nrow(result) + 4)
      even_rows <- rows[rows %% 2 == 0]
      odd_rows <- rows[rows %% 2 == 1]
      addStyle(wb, tab_name, row_even_style, rows = even_rows, cols = 1:ncol(result), gridExpand = TRUE)
      addStyle(wb, tab_name, row_odd_style, rows = odd_rows, cols = 1:ncol(result), gridExpand = TRUE)

      # Set column widths
      setColWidths(wb, tab_name, cols = 1:ncol(result), widths = "auto")
    }
  }

  # Add raw data tab at the end
  addWorksheet(wb, "Raw Data")
  writeData(wb, "Raw Data", data)
  addStyle(wb, "Raw Data", bold_header_style, rows = 1, cols = 1:ncol(data))

  # Apply alternating colors to raw data
  rows <- 2:nrow(data)
  even_rows <- rows[rows %% 2 == 0]
  odd_rows <- rows[rows %% 2 == 1]
  addStyle(wb, "Raw Data", row_even_style, rows = even_rows, cols = 1:ncol(data), gridExpand = TRUE)
  addStyle(wb, "Raw Data", row_odd_style, rows = odd_rows, cols = 1:ncol(data), gridExpand = TRUE)

  # Save workbook
  saveWorkbook(wb, output_file, overwrite = TRUE)
}

# Export the analysis
export_file <- fs::path(output.path.base, "sponsor_compliance_analysis.xlsx")
export_sponsor_analysis(tab.agg.trials.by_sponsor, export_file)
