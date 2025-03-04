library(shiny)
library(tidyverse)
library(ggrepel)
library(DT)
library(textutils)

# UI definition
ui <- fluidPage(
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
		  ))
    ),

    mainPanel(
      tabsetPanel(
	tabPanel("Scatter Plot",
		 plotOutput("compliance_plot", height = "600px")),
	tabPanel("Data Table",
		 DTOutput("sponsor_table"))
      )
    )
  )
)

# Server logic
server <- function(input, output, session) {
  # Read data
  sponsor_data <- reactive({
    ( data <- read_csv("../../figtab/post-rule-to-20240430-by_sponsor/sponsor_compliance_summary.csv")
     |> mutate(
	       schema1.lead_sponsor_name = textutils::HTMLdecode(schema1.lead_sponsor_name)
     )
    )

    # Apply filters
    filtered <- data %>%
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

  # Scatter plot
  output$compliance_plot <- renderPlot({
    data <- sponsor_data()

    p <- ggplot(data, aes(x = n.total, y = n.success)) +
      geom_abline(slope = 1, linetype = "dashed", color = "gray50") +
      geom_point(aes(
	shape = schema1.lead_sponsor_funding_source,
	color = cut(wilson.conf.low,
		   breaks = seq(0, 1, by=0.1),
		   labels = sprintf("%.1f-%.1f", seq(0, 0.9, by=0.1), seq(0.1, 1, by=0.1)))
      ), size = 3)

    if (input$show_labels) {
      p <- p + geom_text_repel(
	aes(label = schema1.lead_sponsor_name,
	    color = cut(wilson.conf.low,
		       breaks = seq(0, 1, by=0.1),
		       labels = sprintf("%.1f-%.1f", seq(0, 0.9, by=0.1), seq(0.1, 1, by=0.1)))),
	size = 3,
	max.overlaps = 20
      )
    }

    p + scale_x_log10() +
      scale_y_log10() +
      labs(
	x = "Total Trials (log scale)",
	y = "Compliant Trials (log scale)",
	shape = "Funding Source",
	color = "Wilson LCB Group"
      ) +
      theme_minimal() +
      theme(legend.position = "bottom")
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
		scrollX = TRUE
	      )) %>%
      formatRound(c("Compliance Rate", "Wilson LCB"), digits = 3)
  })
}

# Run the app
shinyApp(ui = ui, server = server)
