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
		  choices = c("All", "INDUSTRY", "OTHER"),
		  selected = "All"),

      sliderInput("trial_threshold", "Minimum Number of Trials:",
		  min = 1, max = 100, value = 1),

      sliderInput("compliance_range", "Compliance Rate Range:",
		  min = 0, max = 1, value = c(0, 1), step = 0.1),

      checkboxInput("show_labels", "Show Sponsor Labels", value = TRUE),

      selectInput("analysis_type", "Analysis View:",
		  choices = c(
		    "All Sponsors" = "summary",
		    "Perfect Compliance (100%)" = "perfect_compliance",
		    "High Compliance (>50%)" = "high_compliance",
		    "Low Compliance (<10%)" = "low_compliance",
		    "Zero Compliance" = "zero_compliance"
		  )),

      width = 3
    ),

    mainPanel(
      tabsetPanel(
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

  # Update trial threshold slider once on initialization
  observe({
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

    if (input$show_labels) {
      p <- p + geom_text(
	aes(label = schema1.lead_sponsor_name),
	size = 4,
	check_overlap = TRUE,
	hjust = -0.1
      )
    }

    # Convert to plotly with custom configuration
    ggplotly(p, tooltip = "text") %>%
      layout(
	hoverlabel = list(bgcolor = "white"),
	legend = list(orientation = "h", y = -0.2),
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
	      )) %>%
      formatRound(c("Compliance Rate", "Wilson LCB"), digits = 3)
  })
}

# Run the app
shinyApp(ui = ui, server = server)
