library(shiny)
library(tidyverse)
library(arrow)
library(ggrepel)
library(DT)
library(textutils)
library(plotly)

# UI definition
ui <- fluidPage(
  titlePanel("Clinical Trial Sponsor Compliance Analysis"),

  sidebarLayout(
    sidebarPanel(
      selectInput("funding_source", "Funding Source:",
                  choices = c("All"),
                  selected = "All"),

      sliderInput("trial_threshold", "Minimum Number of Trials:",
                  min = 1, max = 100, value = 1),

      sliderInput("compliance_range", "Compliance Rate Range:",
                  min = 0, max = 1, value = c(0, 1), step = 0.1),

      selectInput("analysis_type", "Analysis View:",
                  choices = c(
                    "All Sponsors" = "summary",
                    "Perfect Compliance (100%)" = "perfect_compliance",
                    "High Compliance (>50%)" = "high_compliance",
                    "Low Compliance (<10%)" = "low_compliance",
                    "Zero Compliance" = "zero_compliance"
                  )),

      numericInput("top_n", "Number of Sponsors in Extremes Tables:",
                   value = 10,
                   min = 1,
                   max = 50,
                   step = 1),

      width = 3
    ),

    mainPanel(
      tabsetPanel(
        tabPanel("Extremes",
                 fluidRow(
                   column(12,
                          uiOutput("top_title"),
                          DTOutput("top_table"))
                 ),
                 br(),
                 fluidRow(
                   column(12,
                          uiOutput("bottom_title"),
                          DTOutput("bottom_table"))
                 )),
        tabPanel("Data Table",
                 DTOutput("sponsor_table")),
        tabPanel("Interactive Plot",
                 plotlyOutput("compliance_plot", height = "90vh"))
      ),
      width = 9  # Make main panel wider
    )
  )
)

# Server logic
server <- function(input, output, session) {
  # Initial data load
  raw_data <- arrow::read_parquet("../../brick/post-rule-to-20240430-by_sponsor/sponsor_compliance_summary.parquet")

  # Update on initialisation
  observe({
    # Update funding sources
    funding_sources <- c("All", sort(unique(raw_data$schema1.lead_sponsor_funding_source)))
    updateSelectInput(session, "funding_source",
                      choices = funding_sources,
                      selected = "All")

    # Update trial threshold
    min_trials <- min(raw_data$n.total)
    max_trials <- max(raw_data$n.total)
    updateSliderInput(session, "trial_threshold",
                      min = min_trials,
                      max = max_trials,
                      value = min_trials)
  }, priority = 1000)

  sponsor_data <- reactive({
    # Apply filters
    filtered <- raw_data %>%
      arrange(desc(wilson.conf.low), desc(n.total)) %>%
      filter(n.total >= input$trial_threshold,
             rr.with_extensions >= input$compliance_range[1],
             rr.with_extensions <= input$compliance_range[2])

    if (input$funding_source != "All") {
      filtered <- filtered %>%
        filter(schema1.lead_sponsor_funding_source == input$funding_source)
    }

    # Apply analysis type filters
    filtered <- switch(input$analysis_type,
      "perfect_compliance" = filtered %>% filter(rr.with_extensions == 1),
      "high_compliance" = filtered %>% filter(wilson.conf.low > .50 | rr.with_extensions == 1),
      "low_compliance" = filtered %>% filter(wilson.conf.low < .10 & rr.with_extensions != 0),
      "zero_compliance" = filtered %>% filter(rr.with_extensions == 0),
      filtered # default case - show all
    )

    filtered
  })

  # Interactive scatter plot
  output$compliance_plot <- renderPlotly({
    data <- sponsor_data()

    range_min <- min(1, min(data$n.total), min(data$n.success))
    range_max <- max(max(data$n.total), max(data$n.success))

    # Create base ggplot
    p <- ggplot(data, aes(x = n.total, y = n.success,
                          text = paste0(
                            "Sponsor: ", schema1.lead_sponsor_name,
                            "<br>Total Trials: ", n.total,
                            "<br>Compliant Trials: ", n.success,
                            "<br>Compliance Rate: ", round(rr.with_extensions * 100, 1), "%",
                            "<br>Wilson LCB: ", round(wilson.conf.low * 100, 1), "%"
                          ))) +
      geom_abline(slope = 1, linetype = "dashed", color = "gray50") +
      geom_point(aes(
        shape = schema1.lead_sponsor_funding_source,
        color = cut(wilson.conf.low,
                    breaks = seq(0, 1, by = 0.1),
                    labels = sprintf("%.1f-%.1f", seq(0, 0.9, by = 0.1), seq(0.1, 1, by = 0.1)))
      ), size = 4) +
      scale_x_log10() +
      scale_y_log10() +
      coord_fixed() + # Force square aspect ratio
      labs(
        x = "Total Trials (log scale)",
        y = "Compliant Trials (log scale)",
        shape = "Funding Source",
        color = "Wilson LCB Group"
      ) +
      theme_minimal() +
      theme(
        axis.title = element_text(size = 14),
        axis.text = element_text(size = 12),
        legend.title = element_text(size = 12),
        legend.text = element_text(size = 11),
        legend.position = "bottom"
      )

    plt <- ggplotly(p, tooltip = "text") %>%
      layout(
        hoverlabel = list(bgcolor = "white"),
        autosize = TRUE
      ) %>%
      config(
        scrollZoom = TRUE,
        displayModeBar = TRUE,
        modeBarButtons = list(list(
          "zoom2d",
          "pan2d",
          "zoomIn2d",
          "zoomOut2d",
          "resetScale2d",
          "toImage"
        ))
      )
  })

  # Helper function for table formatting
  format_extreme_table <- function(data, sort_col_idx) {
    datatable(data,
              options = list(
                pageLength = 10,
                order = list(list(sort_col_idx, 'desc')),
                #dom = 't',  # Only show table, no controls
                scrollX = TRUE,
                scrollY = TRUE
              ),
              selection = 'single') %>%
      formatRound(c("Compliance Rate", "Wilson LCB"), digits = 3)
  }

  # Dynamic titles for extremes tables
  output$top_title <- renderUI({
    h4(paste0("Top ", input$top_n, " by Compliance Rate"))
  })

  output$bottom_title <- renderUI({
    h4(paste0("Bottom ", input$top_n, " by Compliance Rate"))
  })

  # Reactive expressions for top and bottom N data
  top_n_data <- reactive({
    sponsor_data() %>%
      arrange(desc(rr.with_extensions), desc(n.total)) %>%
      head(input$top_n)
  })

  bottom_n_data <- reactive({
    sponsor_data() %>%
      arrange(desc(rr.with_extensions), desc(n.total)) %>%
      tail(input$top_n)
  })

  format_table_cols <- function(data) {
    data %>%
      select(
        Sponsor = schema1.lead_sponsor_name,
        `Funding Source` = schema1.lead_sponsor_funding_source,
        `Total Trials` = n.total,
        `Compliant Trials` = n.success,
        `Compliance Rate` = rr.with_extensions,
        `Wilson LCB` = wilson.conf.low
      )
  }

  # Top N table
  output$top_table <- renderDT({
    data <- format_table_cols(top_n_data())
    compliance_col_idx <- which(names(data) == "Compliance Rate")

    format_extreme_table(data, compliance_col_idx)
  })

  # Bottom N table
  output$bottom_table <- renderDT({
    data <- format_table_cols(bottom_n_data())
    compliance_col_idx <- which(names(data) == "Compliance Rate")

    format_extreme_table(data, compliance_col_idx)
  })

  # Data table
  output$sponsor_table <- renderDT({
    data <- sponsor_data() |>
      format_table_cols()

    wilson_col_idx <- which(names(data) == "Wilson LCB")

    datatable(data,
              options = list(
                pageLength = 25,
                order = list(list(wilson_col_idx, 'desc')),
                scrollX = TRUE,
                scrollY = TRUE
              ),
              selection = 'single') %>%
      formatRound(c("Compliance Rate", "Wilson LCB"), digits = 3)
  })

  # Helper function to create ordered list of NCT links
  listify <- function(ncts) {
    if (!all(is.na(ncts)) && length(ncts) > 0) {
      links <- sapply(ncts, function(nct) {
        sprintf('<li><a href="https://clinicaltrials.gov/study/%s" target="_blank">%s</a></li>',
                nct, nct)
      })
      sprintf('<ol>%s</ol>', paste(links, collapse = ""))
    } else {
      "None"
    }
  }

  # Helper function for creating the trial details modal
  show_trial_modal <- function(selected_sponsor) {
    selected_data <- raw_data %>%
      filter(schema1.lead_sponsor_name == selected_sponsor)

    showModal(modalDialog(
      title = paste("Trial Details for", selected_data$schema1.lead_sponsor_name),
      div(
        style = "max-height: 400px; overflow-y: auto;",
        h4("Compliant Trials"),
        HTML(listify(selected_data$ncts.compliant[[1]])),
        hr(),
        h4("Non-compliant Trials"),
        HTML(listify(selected_data$ncts.noncompliant[[1]]))
      ),
      size = "l",
      easyClose = TRUE,
      footer = modalButton("Close")
    ))
  }

  # Modal for displaying NCT details - separate handlers for each table
  observeEvent(input$sponsor_table_rows_selected, {
    req(input$sponsor_table_rows_selected)
    selected_sponsor <- sponsor_data()[input$sponsor_table_rows_selected, ]$schema1.lead_sponsor_name
    show_trial_modal(selected_sponsor)
    dataTableProxy('sponsor_table') %>% selectRows(NULL)
  })

  observeEvent(input$top_table_rows_selected, {
    req(input$top_table_rows_selected)
    selected_sponsor <- top_n_data()[input$top_table_rows_selected, ]$schema1.lead_sponsor_name
    show_trial_modal(selected_sponsor)
    dataTableProxy('top_table') %>% selectRows(NULL)
  })

  observeEvent(input$bottom_table_rows_selected, {
    req(input$bottom_table_rows_selected)
    selected_sponsor <- bottom_n_data()[input$bottom_table_rows_selected, ]$schema1.lead_sponsor_name
    show_trial_modal(selected_sponsor)
    dataTableProxy('bottom_table') %>% selectRows(NULL)
  })
}

# Run the app
shinyApp(ui = ui, server = server)
