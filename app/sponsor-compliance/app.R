library(shiny)
library(tidyverse)
library(ggrepel)
library(DT)
library(textutils)
library(plotly)

# UI definition
ui <- fillPage(
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
  raw_data <- read_csv("../../figtab/post-rule-to-20240430-by_sponsor/sponsor_compliance_summary.csv") %>%
    mutate(
      schema1.lead_sponsor_name = textutils::HTMLdecode(schema1.lead_sponsor_name),
      ncts.compliant = strsplit(ncts.compliant, "\\|"),
      ncts.noncompliant = strsplit(ncts.noncompliant, "\\|")
    )

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
		   breaks = seq(0, 1, by=0.1),
		   labels = sprintf("%.1f-%.1f", seq(0, 0.9, by=0.1), seq(0.1, 1, by=0.1)))
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
  format_sponsor_table <- function(data) {
    datatable(data,
	      options = list(
		pageLength = 10,
		#dom = 't',  # Only show table, no controls
		scrollX = TRUE,
		scrollY = TRUE
	      )) %>%
      formatRound(c("Compliance Rate", "Wilson LCB"), digits = 3)
  }

  # Dynamic titles for extremes tables
  output$top_title <- renderUI({
    h4(paste0("Top ", input$top_n, " by Compliance Rate"))
  })

  output$bottom_title <- renderUI({
    h4(paste0("Bottom ", input$top_n, " by Compliance Rate"))
  })

  # Top N table
  output$top_table <- renderDT({
    data <- sponsor_data() %>%
      arrange(desc(rr.with_extensions), desc(n.total)) %>%
      select(
	Sponsor = schema1.lead_sponsor_name,
	`Funding Source` = schema1.lead_sponsor_funding_source,
	`Total Trials` = n.total,
	`Compliant Trials` = n.success,
	`Compliance Rate` = rr.with_extensions,
	`Wilson LCB` = wilson.conf.low
      ) %>%
      head(input$top_n)

    format_sponsor_table(data)
  })

  # Bottom N table
  output$bottom_table <- renderDT({
    data <- sponsor_data() %>%
      arrange(rr.with_extensions, desc(n.total)) %>%
      select(
	Sponsor = schema1.lead_sponsor_name,
	`Funding Source` = schema1.lead_sponsor_funding_source,
	`Total Trials` = n.total,
	`Compliant Trials` = n.success,
	`Compliance Rate` = rr.with_extensions,
	`Wilson LCB` = wilson.conf.low
      ) %>%
      head(input$top_n)

    format_sponsor_table(data)
  })

  # Data table
  output$sponsor_table <- renderDT({
    data <- sponsor_data() %>%
      select(
	Sponsor = schema1.lead_sponsor_name,
	`Funding Source` = schema1.lead_sponsor_funding_source,
	`Total Trials` = n.total,
	`Compliant Trials` = n.success,
	`Compliance Rate` = rr.with_extensions,
	`Wilson LCB` = wilson.conf.low
      )

    datatable(data,
	      options = list(
		pageLength = 25,
		order = list(list(4, 'desc')),
		scrollX = TRUE,
		scrollY = TRUE
	      ),
	      selection = 'single') %>%
      formatRound(c("Compliance Rate", "Wilson LCB"), digits = 3)
  })

  # Helper function to create ordered list of NCT links
  listify <- function(ncts) {
    if (!is.na(ncts) && length(ncts) > 0) {
      links <- sapply(ncts, function(nct) {
	sprintf('<li><a href="https://clinicaltrials.gov/study/%s" target="_blank">%s</a></li>',
	       nct, nct)
      })
      sprintf('<ol>%s</ol>', paste(links, collapse = ""))
    } else {
      "None"
    }
  }

  # Modal for displaying NCT details
  observeEvent(input$sponsor_table_rows_selected, {
    if (!is.null(input$sponsor_table_rows_selected)) {
      # Get the sponsor name from the filtered data
      selected_sponsor <- sponsor_data()[input$sponsor_table_rows_selected, ]$schema1.lead_sponsor_name

      # Find matching row in raw_data
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
  })
}

# Run the app
shinyApp(ui = ui, server = server)
