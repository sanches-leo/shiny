library(shiny)
library(lacen)
library(dplyr)

options(shiny.launch.browser = TRUE)

# UI Definition
ui <- navbarPage(
    "LACEN Pipeline",
    id = "main_nav",
    tabPanel("Greetings",
        value = "greetings",
        fluidPage(
            titlePanel("Welcome to the LACEN Shiny App"),
            p("This application provides a graphical interface for the LACEN pipeline."),
            actionButton("start_btn", "Start")
        )
    ),
    tabPanel("Load Data",
        value = "load_data",
        fluidPage(
            titlePanel("Load Data"),
            sidebarLayout(
                sidebarPanel(
                    fileInput("annotationData_file", "Upload Annotation Data (TSV)", accept = ".tsv"),
                    fileInput("expressionDGEData_file", "Upload Expression DGE Data (TSV)", accept = ".tsv"),
                    fileInput("ncAnnotation_file", "Upload ncAnnotation Data (TSV)", accept = ".tsv"),
                    fileInput("rawExpressionData_file", "Upload Raw Expression Data (TSV)", accept = ".tsv"),
                    fileInput("traitsData_file", "Upload Traits Data (TSV)", accept = ".tsv"),
                    hr(),
                    actionButton("use_demo_data_btn", "Use Demo Data"),
                    hr(),
                    actionButton("check_data_btn", "Check Data Format", disabled = TRUE)
                ),
                mainPanel(
                    verbatimTextOutput("check_data_output")
                )
            )
        )
    ),
    tabPanel("Filter and Transform",
        value = "filter_transform",
        fluidPage(
            titlePanel("Filter and Transform"),
            sidebarLayout(
                sidebarPanel(
                    numericInput("pThreshold", "P-value Threshold", 0.05, min = 0, max = 1, step = 0.01),
                    numericInput("fcThreshold", "Fold Change Threshold", 1.5, min = 0, step = 0.1),
                    actionButton("run_filter_transform_btn", "Run Filter and Transform")
                ),
                mainPanel(
                    verbatimTextOutput("filter_transform_output")
                )
            )
        )
    ),
    tabPanel("Clustering",
        value = "clustering",
        fluidPage(
            titlePanel("Clustering"),
            sidebarLayout(
                sidebarPanel(
                    numericInput("height_input", "Select Height", 0),
                    actionButton("rerun_clustering_btn", "Re-run Clustering"),
                    hr(),
                    actionButton("accept_height_btn", "Accept Height and Proceed")
                ),
                mainPanel(
                    imageOutput("cluster_tree_plot")
                )
            )
        )
    ),
    tabPanel("Soft Threshold",
        value = "soft_threshold",
        fluidPage(
            titlePanel("Soft Threshold"),
            sidebarLayout(
                sidebarPanel(
                    numericInput("indicePower_input", "Select Indice Power", 9, min = 1, max = 20),
                    actionButton("run_soft_threshold_btn", "Select Power and Proceed")
                ),
                mainPanel(
                    imageOutput("soft_threshold_plot")
                )
            )
        )
    ),
    tabPanel("Summarize and Enrich",
        value = "summarize_enrich",
        fluidPage(
            titlePanel("Summarize and Enrich Modules"),
            fluidRow(
                column(6, tags$a(
                    href = "enrichedgraph.png", target = "_blank",
                    tags$img(src = "enrichedgraph.png", style = "max-width: 100%; height: auto;")
                )),
                column(6, tags$a(
                    href = "stackedplot.png", target = "_blank",
                    tags$img(src = "stackedplot.png", style = "max-width: 100%; height: auto;")
                ))
            )
        )
    ),
    tabPanel("Heatmap",
        value = "heatmap",
        fluidPage(
            titlePanel("Heatmap"),
            sidebarLayout(
                sidebarPanel(
                    numericInput("module_input", "Select Module", 1, min = 1),
                    numericInput("submodule_input", "Select Submodule (0 for FALSE)", 0, min = 0),
                    actionButton("run_heatmap_btn", "Generate Heatmap")
                ),
                mainPanel(
                    imageOutput("heatmap_plot")
                )
            )
        )
    ),
    tabPanel("LNC-centric Analysis",
        value = "lnc_centric",
        fluidPage(
            titlePanel("LNC-centric Analysis"),
            sidebarLayout(
                sidebarPanel(
                    selectizeInput("lncSymbol_input", "LNC Symbol", choices = NULL),
                    numericInput("mGenesNet_input", "mGenesNet", 80),
                    numericInput("nTerm_input", "nTerm", 20),
                    selectInput("sources_input", "Sources",
                        choices = c("GO", "GO:BP", "GO:MF", "GO:CC", "KEGG", "REAC")
                    ),
                    actionButton("run_lnc_analysis_btn", "Run Analysis")
                ),
                mainPanel(
                    fluidRow(
                        column(6, uiOutput("lnc_net_plot_output")),
                        column(6, uiOutput("lnc_enr_plot_output"))
                    )
                )
            )
        )
    )
)

# Server Logic
server <- function(input, output, session) {
    # Reactive values to store data and state
    values <- reactiveValues(
        lacenObject = NULL,
        data_checked = FALSE,
        lncList = NULL
    )

    # 1.0 Greetings
    observeEvent(input$start_btn, {
        updateNavbarPage(session, "main_nav", selected = "load_data")
    })

    # 2.0 Loading Data
    observe({
        # Enable check data button only if all files are uploaded
        if (!is.null(input$annotationData_file) && !is.null(input$expressionDGEData_file) &&
            !is.null(input$ncAnnotation_file) && !is.null(input$rawExpressionData_file) &&
            !is.null(input$traitsData_file)) {
            updateActionButton(session, "check_data_btn", disabled = FALSE)
        }
    })

    observeEvent(input$use_demo_data_btn, {
        # Load demo data
        data("annotation_data", "expression_DGE", "nc_annotation", "raw_expression", "traits")

        # Initialize lacenObject
        values$lacenObject <- initLacen(
            annotationData = annotation_data,
            datCounts = raw_expression,
            datExpression = expression_DGE,
            datTraits = traits,
            ncAnnotation = nc_annotation
        )

        output$check_data_output <- renderPrint({
            "Demo data loaded. Click 'Check Data Format'."
        })
        updateActionButton(session, "check_data_btn", disabled = FALSE)
    })

    observeEvent(input$check_data_btn, {
        if (!is.null(values$lacenObject)) { # Demo data path
            check_result <- checkData(values$lacenObject)
        } else { # Uploaded data path
            req(
                input$annotationData_file, input$expressionDGEData_file, input$ncAnnotation_file,
                input$rawExpressionData_file, input$traitsData_file
            )

            annotationData <- read.delim(input$annotationData_file$datapath, sep = "	")
            expressionDGEData <- read.delim(input$expressionDGEData_file$datapath, sep = "	")
            ncAnnotation <- read.delim(input$ncAnnotation_file$datapath, sep = "	")
            rawExpressionData <- read.delim(input$rawExpressionData_file$datapath, sep = "	")
            traitsData <- read.delim(input$traitsData_file$datapath, sep = "	")

            values$lacenObject <- initLacen(
                annotationData = annotationData,
                datCounts = rawExpressionData,
                datExpression = expressionDGEData,
                datTraits = traitsData,
                ncAnnotation = ncAnnotation
            )
            check_result <- checkData(values$lacenObject)
        }

        if (isTRUE(check_result)) {
            values$data_checked <- TRUE
            output$check_data_output <- renderPrint({
                "Data check passed! Proceeding to the next step."
            })
            updateNavbarPage(session, "main_nav", selected = "filter_transform")
        } else {
            output$check_data_output <- renderPrint({
                check_result
            })
        }
    })

    # 3.0 Filter and Transform
    observeEvent(input$run_filter_transform_btn, {
        req(values$lacenObject)
        values$lacenObject <- filterTransform(
            lacenObject = values$lacenObject,
            pThreshold = input$pThreshold,
            fcThreshold = input$fcThreshold,
            filterMethod = "DEG"
        )
        output$filter_transform_output <- renderPrint({
            "Filter and transform complete. Proceeding to clustering."
        })
        updateNavbarPage(session, "main_nav", selected = "clustering")

        # Initial clustering plot
        selectOutlierSample(values$lacenObject, height = FALSE, plot = TRUE, filename = "clusterTree.png")
        output$cluster_tree_plot <- renderImage(
            {
                list(src = "clusterTree.png", contentType = "image/png", alt = "Cluster Tree")
            },
            deleteFile = TRUE
        )
    })

    # 4.0 Clustering
    observeEvent(input$rerun_clustering_btn, {
        req(values$lacenObject)
        height_val <- if (input$height_input == 0) FALSE else input$height_input
        selectOutlierSample(values$lacenObject, height = height_val, plot = TRUE, filename = "clusterTree.png")
        output$cluster_tree_plot <- renderImage(
            {
                list(src = "clusterTree.png", contentType = "image/png", alt = "Cluster Tree")
            },
            deleteFile = TRUE
        )
    })

    observeEvent(input$accept_height_btn, {
        req(values$lacenObject)
        height_val <- if (input$height_input == 0) FALSE else input$height_input
        values$lacenObject <- cutOutlierSample(values$lacenObject, height = height_val)
        updateNavbarPage(session, "main_nav", selected = "soft_threshold")

        # Initial soft threshold plot
        plotSoftThreshold(values$lacenObject, filename = "indicePower.png", maxBlockSize = 10000, plot = FALSE)
        output$soft_threshold_plot <- renderImage(
            {
                list(src = "indicePower.png", contentType = "image/png", alt = "Soft Threshold Plot")
            },
            deleteFile = TRUE
        )
    })

    # 5.0 Soft Threshold
    observeEvent(input$run_soft_threshold_btn, {
        req(values$lacenObject)

        values$lacenObject <- selectSoftThreshold(
            lacenObject = values$lacenObject,
            indicePower = input$indicePower_input
        )

        updateNavbarPage(session, "main_nav", selected = "summarize_enrich")

        # Save high-res images to the www directory
        enriched_path <- file.path("www", "enrichedgraph.png")
        stacked_path <- file.path("www", "stackedplot.png")

        values$lacenObject <- summarizeAndEnrichModules(
            lacenObject = values$lacenObject,
            maxBlockSize = 40000,
            filename = enriched_path
        )

        stackedBarplot(
            values$lacenObject,
            filename = stacked_path,
            plot = FALSE
        )

        output$enriched_graph_plot <- renderImage(
            {
                list(
                    src = enriched_path,
                    contentType = "image/png",
                    alt = "Enriched Graph",
                    width = 800,
                    height = 800
                )
            },
            deleteFile = FALSE
        )

        output$stacked_barplot_plot <- renderImage(
            {
                list(
                    src = stacked_path,
                    contentType = "image/png",
                    alt = "Stacked Barplot",
                    width = 1000,
                    height = 600
                )
            },
            deleteFile = FALSE
        )
    })

    # 6.0 Heatmap
    observeEvent(input$run_heatmap_btn, {
        req(values$lacenObject)
        submodule_val <- if (input$submodule_input == 0) FALSE else input$submodule_input
        heatmapTopConnectivity(
            lacenObject = values$lacenObject,
            module = input$module_input,
            submodule = submodule_val,
            filename = "mod.png"
        )
        output$heatmap_plot <- renderImage(
            {
                list(src = "mod.png", contentType = "image/png", alt = "Module Heatmap")
            },
            deleteFile = TRUE
        )
    })

    # LNC-centric Analysis Tab Activation
    observeEvent(input$main_nav, {
        if (input$main_nav == "lnc_centric" && !is.null(values$lacenObject)) {
            lncList <- values$lacenObject$summdf$gene_name[values$lacenObject$summdf$is_nc]
            updateSelectizeInput(session, "lncSymbol_input", choices = lncList, server = TRUE)
        }
    })


    # 7.0 lnc-centric analysis
    observeEvent(input$run_lnc_analysis_btn, {
        req(values$lacenObject, input$lncSymbol_input)
        # Save high-res images to the www directory
        net_path <- file.path("www", "net_plot.png")
        enr_path <- file.path("www", "enr_plot.png")

        lncRNAEnrich(
            lncName = input$lncSymbol_input,
            lacenObject = values$lacenObject,
            nGenesNet = input$mGenesNet_input,
            nTerm = input$nTerm_input,
            sources = input$sources_input,
            netPath = net_path,
            enrPath = enr_path
        )

        output$lnc_net_plot_output <- renderUI({
            tags$a(
                href = "net_plot.png", target = "_blank",
                tags$img(src = "net_plot.png", style = "max-width: 100%; height: auto;")
            )
        })

        output$lnc_enr_plot_output <- renderUI({
            tags$a(
                href = "enr_plot.png", target = "_blank",
                tags$img(src = "enr_plot.png", style = "max-width: 100%; height: auto;")
            )
        })
    })
}

# Run the application
shinyApp(ui = ui, server = server)
