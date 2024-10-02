library(gt)
library(gtsummary)

generate_table_1 <- function(df) {
  
  # .... Selecting relevant columns for Table 1 ....
  df <- df %>% 
    select(
      rr.results_reported_12mo,
      rr.results_reported_5yr,
      rr.primary_purpose,
      rr.intervention_type,
      rr.phase,
      rr.funding,
      common.pc_year_imputed
      # U.S. site, skip recruitment completed, fda oversite
    ) %>% 
    mutate(
        rr.primary_purpose = rr.primary_purpose %>% 
          forcats::fct_collapse( Other = c('Diagnostic', 'Other') )
    )
  
  # .... Cleaning columns into factors for table display ....
  df$rr.primary_purpose <- factor(df$rr.primary_purpose, 
                                  levels=c("Treatment", "Prevention", "Other"))
  df$rr.intervention_type <- factor(df$rr.intervention_type, 
                                    levels=c("Drug", "Biological", "Device", "Other"))
  df$rr.phase <- factor(df$rr.phase, 
                        levels=c("1-2", "2", "2-3", "3", "4", "Not applicable"))
  df$rr.funding <- factor(df$rr.funding,
                          levels=c("Industry", "NIH", "Other"))
  
  # .... Selecting subsets of data (time to report) for additional columns ....
  df_12mo <- df %>% filter(rr.results_reported_12mo == TRUE)
  df_5yr <- df %>% filter(rr.results_reported_5yr == TRUE)

  
  # .... For each dataframe, rename columns and select columns to display ....
  list_dfs <- list(df, df_12mo, df_5yr) %>% purrr::map(
    ~.x %>% mutate(
      'Primary Purpose' = rr.primary_purpose,
      'Intervention Type' = rr.intervention_type,
      'Phase Type' = rr.phase,
      'Funding Type' = rr.funding,
      'Completed Year' = common.pc_year_imputed
    ) %>% 
      select(
        'Primary Purpose',
        'Intervention Type',
        'Phase Type',
        'Funding Type',
        'Primary Completed Year'
      ) 
  )
  
  df <- list_dfs[[1]]
  df_12mo <- list_dfs[[2]]
  df_5yr <- list_dfs[[3]]
  
  # .... Create tables to merge ....
  tbl_all <- df %>% tbl_summary() %>% bold_labels() 
  
  tbl_12mo <- df_12mo %>% tbl_summary() %>% bold_labels() 
  tbl_5yr <- df_5yr %>% tbl_summary() %>% bold_labels()
  
  tbl_combined <- tbl_merge(
    tbls = list(tbl_all, tbl_12mo, tbl_5yr), 
    tab_spanner=c(
      "All Trials", 
      "Trials with Results \n Reported by 12 Mo", 
      "Trials with Results \n Reported by 5 Yr"
      )
    ) 

  # .... Styling table for alternate row highlighting ....
  N_alternate_rows <- nrow(as_gt(tbl_all)[["_data"]])

  tbl_styled <- tbl_combined %>% as_gt() %>% tab_style(
    style = list(cell_fill(color = "#f9f9f9")),
    locations = cells_body(
      rows = seq(1, N_alternate_rows, by = 2) # Select alternating rows
    )
  ) 
  return(tbl_styled)
}


# .... Load dataframe, create table, export table.... 

df <- anderson2015.original$hlact.studies
table_1 <- generate_table_1(df)
table_1

latex_code <- table_1 %>% as_latex()
writeLines(as.character(latex_code), "../output/table1.tex")


