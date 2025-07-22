library(shiny)
library(shinyjs)
library(lacen)
library(dplyr)

options(shiny.launch.browser = TRUE)
options(shiny.maxRequestSize = 100 * 1024^2) 

# UI Definition
ui <- fluidPage(
    useShinyjs(),
    tags$head(
        tags$link(rel = "stylesheet", type = "text/css", href = "styles.css"),
        tags$script(src = "script.js")
    ),
    div(id = "loading-overlay", div(class = "loader"), p("Processing..."), style = "display: none;"),
        div(id = "login_screen",
        fluidPage(
            titlePanel("User Login"),
            textInput("user_id", "Enter User ID:"),
            passwordInput("password", "Enter Password:"),
            actionButton("login_btn", "Login"),
            textOutput("login_message")
        )
    ),
    div(id = "main_app", style = "display: none;",
        navbarPage(
            "LACEN Pipeline",
            id = "main_nav",
            tabPanel("Greetings",
                value = "greetings",
                fluidPage(
                    actionButton("help_greetings", "Help", class = "pull-right"),
                    titlePanel("Welcome to the LACEN Shiny App"),
                    p("This application provides a graphical interface for the LACEN pipeline."),
                    actionButton("start_btn", "Start")
                )
            ),
            tabPanel("Load Data",
                value = "load_data",
                fluidPage(
                    actionButton("help_load_data", "Help", class = "pull-right"),
                    titlePanel("Load Data"),
                    sidebarLayout(
                        sidebarPanel(
                            fileInput("rawExpressionData_file", "Upload Raw Expression Data (CSV)", accept = ".csv"),
                            fileInput("expressionDGEData_file", "Upload Expression DGE Data (CSV)", accept = ".csv"),
                            fileInput("traitsData_file", "Upload Traits Data (CSV)", accept = ".csv"),
                            fileInput("annotationData_file",
                                      "Upload Annotation Data (GTF or CSV)",
                                      accept = c(".csv",
                                                 ".gtf",
                                                 ".gtf.gz")),
                            fileInput("ncAnnotation_file",
                                      "Upload ncAnnotation Data (GTF or CSV)",
                                      accept = c(".csv",
                                                 ".gtf",
                                                 ".gtf.gz")),
                            selectInput("organism", "Select Organism",
                                        choices = c("Homo sapiens", "Mus musculus", "Rattus norvegicus", "Danio rerio",
                                                    "Drosophila melanogaster", "Caenorhabditis elegans", "Saccharomyces cerevisiae",
                                                    "Arabidopsis thaliana", "Gallus gallus", "Sus scrofa", "Bos taurus",
                                                    "Canis familiaris"),
                                        selected = "Homo sapiens"),
                            hr(),
                            actionButton("use_demo_data_btn", "Use Demo Data"),
                            hr(),
                            actionButton("check_data_btn", "Check Data Format", disabled = TRUE),

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
                    actionButton("help_filter_transform", "Help", class = "pull-right"),
                    titlePanel("Filter and Transform"),
                    sidebarLayout(
                        sidebarPanel(
                            selectInput("filterMethod", "Filter Method",
                                        choices = c("DEG", "var"), selected = "DEG"),
                            conditionalPanel(
                                condition = "input.filterMethod == 'DEG'",
                                numericInput("pThreshold", "P-value Threshold", 0.05, min = 0, max = 1, step = 0.01),
                                numericInput("fcThreshold", "Fold Change Threshold", 1.5, min = 0, step = 0.1)
                            ),
                            conditionalPanel(
                                condition = "input.filterMethod == 'var'",
                                numericInput("topVarGenes", "Top Variable Genes", 5000, min = 1)
                            ),
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
                    actionButton("help_clustering", "Help", class = "pull-right"),
                    titlePanel("Clustering"),
                    sidebarLayout(
                        sidebarPanel(
                            numericInput("height_input", "Select Height", 0),
                            actionButton("rerun_clustering_btn", "Re-run Clustering"),
                            hr(),
                            actionButton("accept_height_btn", "Accept Height and Proceed")
                        ),
                        mainPanel(
                            uiOutput("cluster_tree_plot")
                        )
                    )
                )
            ),
            tabPanel("Soft Threshold",
                value = "soft_threshold",
                fluidPage(
                    actionButton("help_soft_threshold", "Help", class = "pull-right"),
                    titlePanel("Soft Threshold"),
                    sidebarLayout(
                        sidebarPanel(
                            numericInput("indicePower_input", "Select Indice Power", 9, min = 1, max = 20),
                            actionButton("run_soft_threshold_btn", "Select Power and Proceed")
                        ),
                        mainPanel(
                            uiOutput("soft_threshold_plot")
                        )
                    )
                )
            ),
            tabPanel("Bootstrap",
                value = "bootstrap",
                fluidPage(
                    actionButton("help_bootstrap", "Help", class = "pull-right"),
                    titlePanel("Bootstrap Analysis (Optional)"),
                    p("This step is optional and can be very time-consuming (from hours to days). It remakes the network multiple times to find the most robust modules."),
                    hr(),
                    actionButton("run_bootstrap_btn", "Run Bootstrap Analysis"),
                    actionButton("skip_bootstrap_btn", "Skip and Proceed to Summarize/Enrich"),
                    hr(),
                    uiOutput("bootstrap_plots_output"),
                    hr(),
                    div(id = "bootstrap_threshold_div", style = "display: none;",
                        numericInput("bootstrap_threshold_input", "Bootstrap Threshold", value = 0.8, min = 0, max = 1, step = 0.05),
                        actionButton("set_bootstrap_btn", "Apply Threshold and Proceed")
                    )
                )
            ),
            tabPanel("Summarize and Enrich",
                value = "summarize_enrich",
                fluidPage(
                    actionButton("help_summarize_enrich", "Help", class = "pull-right"),
                    titlePanel("Summarize and Enrich Modules"),
                    actionButton("run_summarize_enrich_btn", "Run Summarize and Enrich"),
                    hr(),
                    fluidRow(
                    column(6, uiOutput("enriched_graph_output")),
                    column(6, uiOutput("stacked_barplot_output"))
                )
                )
            ),
            tabPanel("Heatmap",
                value = "heatmap",
                fluidPage(
                    actionButton("help_heatmap", "Help", class = "pull-right"),
                    titlePanel("Heatmap"),
                    sidebarLayout(
                        sidebarPanel(
                            numericInput("module_input", "Select Module", 1, min = 1),
                            numericInput("submodule_input", "Select Submodule (0 for FALSE)", 0, min = 0),
                            actionButton("run_heatmap_btn", "Generate Heatmap")
                        ),
                        mainPanel(
                            uiOutput("heatmap_plot")
                        )
                    )
                )
            ),
            tabPanel("LNC-centric Analysis",
                value = "lnc_centric",
                fluidPage(
                    actionButton("help_lnc_centric", "Help", class = "pull-right"),
                    titlePanel("LNC-centric Analysis"),
                    sidebarLayout(
                        sidebarPanel(
                            selectizeInput("lncSymbol_input", "LNC Symbol", choices = NULL),
                            numericInput("nGenesNet_input", "nGenesNet", 20),
                            numericInput("nTerm_input", "nTerm", 10),
                            numericInput("nGenes_input", "nGenes", 100),
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
            ),
            tabPanel("Download",
                value = "download",
                fluidPage(
                    titlePanel("Download Data"),
                    p("Click the button below to download all the generated data as a zip file."),
                    downloadButton("download_data_btn", "Download All Data")
                )
            )
        )
    )
)

# Server Logic
server <- function(input, output, session) {
    # Help button observers
    observeEvent(input$help_greetings, {
        showModal(modalDialog(
            title = "Greetings",
            includeMarkdown("docs/greetings.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_load_data, {
        showModal(modalDialog(
            title = "Load Data",
            includeMarkdown("docs/loadData.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_filter_transform, {
        showModal(modalDialog(
            title = "Filter and Transform",
            includeMarkdown("docs/filterTransform.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_clustering, {
        showModal(modalDialog(
            title = "Clustering",
            includeMarkdown("docs/clustering.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_soft_threshold, {
        showModal(modalDialog(
            title = "Soft Threshold",
            includeMarkdown("docs/softThreshold.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_bootstrap, {
        showModal(modalDialog(
            title = "Bootstrap",
            includeMarkdown("docs/bootstrap.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_summarize_enrich, {
        showModal(modalDialog(
            title = "Summarize and Enrich",
            includeMarkdown("docs/summarizeEnrich.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_heatmap, {
        showModal(modalDialog(
            title = "Heatmap",
            includeMarkdown("docs/heatmap.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })
    observeEvent(input$help_lnc_centric, {
        showModal(modalDialog(
            title = "LNC-centric Analysis",
            includeMarkdown("docs/lncCentric.md"),
            easyClose = TRUE,
            footer = NULL
        ))
    })

    # Reactive values to store data and state
    values <- reactiveValues(
        lacenObject = NULL,
        data_checked = FALSE,
        lncList = NULL,
        user_id = NULL
    )

    # Reactive observer to regenerate plots when lacenObject is loaded from a saved session
    observeEvent(input$main_nav, {
        req(values$lacenObject)
        if (identical(input$main_nav, "heatmap")) {

            # Regenerate Cluster Tree Plot
            cluster_tree_path_threshold <- file.path("users", values$user_id, "clusterTreeThreshold.png")
            cluster_tree_path_initial <- file.path("users", values$user_id, "clusterTree.png")
            # Decide which cluster tree image to show
            final_cluster_path <- if (file.exists(cluster_tree_path_threshold)) {
                file.path("users_data", values$user_id, "clusterTreeThreshold.png")
            } else if (file.exists(cluster_tree_path_initial)) {
                file.path("users_data", values$user_id, "clusterTree.png")
            } else {
                NULL
            }

            if (!is.null(final_cluster_path)) {
                output$cluster_tree_plot <- renderUI({
                    tags$a(
                        href = final_cluster_path, target = "_blank",
                        tags$img(src = final_cluster_path, style = "max-width: 100%; height: auto;")
                    )
                })
            }

            # Regenerate Soft Threshold Plot
            soft_threshold_path_file <- file.path("users", values$user_id, "indicePower.png")
            if (file.exists(soft_threshold_path_file)) {
                soft_threshold_path_url <- file.path("users_data", values$user_id, "indicePower.png")
                output$soft_threshold_plot <- renderUI({
                    tags$a(
                        href = soft_threshold_path_url, target = "_blank",
                        tags$img(src = soft_threshold_path_url, style = "max-width: 100%; height: auto;")
                    )
                })
            }

            # Regenerate Summarize and Enrich Plots
            enriched_graph_path_file <- file.path("users", values$user_id, "enrichedgraph.png")
            if (file.exists(enriched_graph_path_file)) {
                enriched_graph_path_url <- file.path("users_data", values$user_id, "enrichedgraph.png")
                output$enriched_graph_output <- renderUI({
                    tags$a(
                        href = enriched_graph_path_url, target = "_blank",
                        tags$img(src = enriched_graph_path_url, style = "max-width: 100%; height: auto;")
                    )
                })
            }

            stacked_barplot_path_file <- file.path("users", values$user_id, "stackedplot.png")
            if (file.exists(stacked_barplot_path_file)) {
                stacked_barplot_path_url <- file.path("users_data", values$user_id, "stackedplot.png")
                output$stacked_barplot_output <- renderUI({
                    tags$a(
                        href = stacked_barplot_path_url, target = "_blank",
                        tags$img(src = stacked_barplot_path_url, style = "max-width: 100%; height: auto;")
                    )
                })
            }
        }
    })

    # Login screen logic
    observeEvent(input$login_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            user_id <- trimws(input$user_id)
            password <- input$password
            correct_password <- trimws(readLines(".pass", n = 1))

            if (user_id == "" || password == "") {
                output$login_message <- renderText({"User ID and password cannot be empty."})
            } else if (password != correct_password) {
                output$login_message <- renderText({"Incorrect password."})
            } else {
                user_dir <- file.path("users", user_id)
                if (!dir.exists(user_dir)) dir.create(user_dir, recursive = TRUE)
                addResourcePath("users_data", "users")
                values$user_id <- user_id

                lacen_object_path <- file.path("users", values$user_id, "lacenObject.rds")
                if (file.exists(lacen_object_path)) {
                    values$lacenObject <- readRDS(lacen_object_path)
                    shinyjs::hide("login_screen")
                    shinyjs::show("main_app")
                    updateNavbarPage(session, "main_nav", selected = "heatmap")
                } else {
                    shinyjs::hide("login_screen")
                    shinyjs::show("main_app")
                }
            }
        }, error = function(e) {
            output$login_message <- renderText({ paste("An error occurred:", e$message) })
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # 1.0 Greetings
    observeEvent(input$start_btn, {
        updateNavbarPage(session, "main_nav", selected = "load_data")
    })

    # 2.0 Loading Data
    observe({
        all_files_present <- !is.null(input$annotationData_file) && 
                             !is.null(input$expressionDGEData_file) &&
                             !is.null(input$ncAnnotation_file) && 
                             !is.null(input$rawExpressionData_file) &&
                             !is.null(input$traitsData_file)
        updateActionButton(session, "check_data_btn", disabled = !all_files_present)
    })

    observeEvent(input$use_demo_data_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            data("annotation_data", "expression_DGE", "nc_annotation", "raw_expression", "traits")
            values$lacenObject <- initLacen(
                annotationData = annotation_data,
                datCounts = raw_expression,
                datExpression = expression_DGE,
                datTraits = traits,
                ncAnnotation = nc_annotation
            )
            output$check_data_output <- renderPrint({"Demo data loaded. Click 'Check Data Format'."})
            updateActionButton(session, "check_data_btn", disabled = FALSE)
        }, error = function(e) {
            showNotification(paste("Error loading demo data:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    check_output_text <- reactiveVal("Data has not been checked yet.")
    output$check_data_output <- renderPrint({ cat(check_output_text()) })

    observeEvent(input$check_data_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            lacen_object_to_check <- NULL
            if (!is.null(values$lacenObject)) {
                lacen_object_to_check <- values$lacenObject
            } else {
                req(input$annotationData_file, input$expressionDGEData_file, input$ncAnnotation_file, input$rawExpressionData_file, input$traitsData_file)
                expressionDGEData <- read.csv(input$expressionDGEData_file$datapath)
                rawExpressionData <- read.csv(input$rawExpressionData_file$datapath, row.names = 1, check.names = FALSE)
                traitsData <- read.csv(input$traitsData_file$datapath)
                ann_ext <- tolower(sub(".*\\.", "", input$annotationData_file$name))
                annotationData <- if (ann_ext == "csv") read.csv(input$annotationData_file$datapath) else loadGTF(input$annotationData_file$datapath)
                ncann_ext <- tolower(sub(".*\\.", "", input$ncAnnotation_file$name))
                ncAnnotation <- if (ncann_ext == "csv") read.csv(input$ncAnnotation_file$datapath) else loadGTF(input$ncAnnotation_file$datapath)
                
                values$lacenObject <- lacen_object_to_check <- initLacen(
                    annotationData = annotationData, datCounts = rawExpressionData,
                    datExpression = expressionDGEData, datTraits = traitsData,
                    ncAnnotation = ncAnnotation
                )
            }

            warnings_captured <- c()
            check_result <- withCallingHandlers(
                checkData(lacen_object_to_check),
                warning = function(w) {
                    warnings_captured <<- c(warnings_captured, w$message)
                    invokeRestart("muffleWarning")
                }
            )

            if (isTRUE(check_result)) {
                values$data_checked <- TRUE
                check_output_text("Data check passed! Proceeding to the next step.")
                updateNavbarPage(session, "main_nav", selected = "filter_transform")
            } else {
                check_output_text(paste(warnings_captured, collapse = "\n"))
            }
        }, error = function(e) {
            check_output_text(paste("An error occurred during data check:", e$message))
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # 3.0 Filter and Transform
    observeEvent(input$run_filter_transform_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject)
            if (input$filterMethod == "DEG") {
                values$lacenObject <- filterTransform(values$lacenObject, pThreshold = input$pThreshold, fcThreshold = input$fcThreshold, filterMethod = "DEG")
            } else {
                values$lacenObject <- filterTransform(values$lacenObject, topVarGenes = input$topVarGenes, filterMethod = "var")
            }
            output$filter_transform_output <- renderPrint({"Filter and transform complete. Proceeding to clustering."})
            updateNavbarPage(session, "main_nav", selected = "clustering")
            
            file_name <- file.path("users", values$user_id, "clusterTree.png")
            selectOutlierSample(values$lacenObject, height = FALSE, plot = FALSE, filename = file_name)
            output$cluster_tree_plot <- renderUI({
                tags$a(href = file.path("users_data", values$user_id, "clusterTree.png"), target = "_blank",
                       tags$img(src = file.path("users_data", values$user_id, "clusterTree.png"), style = "max-width: 100%; height: auto;"))
            })
        }, error = function(e) {
            showNotification(paste("Error during Filter/Transform:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # 4.0 Clustering
    observeEvent(input$rerun_clustering_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject)
            height_val <- if (input$height_input == 0) FALSE else input$height_input
            file_name <- file.path("users", values$user_id, "clusterTreeThreshold.png")
            selectOutlierSample(values$lacenObject, height = height_val, plot = FALSE, filename = file_name)
            output$cluster_tree_plot <- renderUI({
                tags$a(href = file.path("users_data", values$user_id, "clusterTreeThreshold.png"), target = "_blank",
                       tags$img(src = file.path("users_data", values$user_id, "clusterTreeThreshold.png"), style = "max-width: 100%; height: auto;"))
            })
        }, error = function(e) {
            showNotification(paste("Error during clustering:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    observeEvent(input$accept_height_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject)
            height_val <- if (input$height_input == 0) FALSE else input$height_input
            values$lacenObject <- cutOutlierSample(values$lacenObject, height = height_val)
            updateNavbarPage(session, "main_nav", selected = "soft_threshold")
            file_name <- file.path("users", values$user_id, "indicePower.png")
            plotSoftThreshold(values$lacenObject, filename = file_name, maxBlockSize = 20000, plot = FALSE)
            output$soft_threshold_plot <- renderUI({
                tags$a(href = file.path("users_data", values$user_id, "indicePower.png"), target = "_blank",
                       tags$img(src = file.path("users_data", values$user_id, "indicePower.png"), style = "max-width: 100%; height: auto;"))
            })
        }, error = function(e) {
            showNotification(paste("Error accepting height:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # 5.0 Soft Threshold
    observeEvent(input$run_soft_threshold_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject)
            values$lacenObject <- selectSoftThreshold(values$lacenObject, indicePower = input$indicePower_input)
            updateNavbarPage(session, "main_nav", selected = "bootstrap")
        }, error = function(e) {
            showNotification(paste("Error during soft threshold selection:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # Bootstrap
    observeEvent(input$run_bootstrap_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        showNotification("Running bootstrap analysis. This may take a very long time.", type = "warning", duration = NULL)
        tryCatch({
            req(values$lacenObject)
            bootstrap_csv_path <- file.path("users", values$user_id, "bootstrap.csv")
            mod_groups_plot_path <- file.path("users", values$user_id, "moduleGroups.png")
            stability_plot_path <- file.path("users", values$user_id, "moduleStability.png")

            values$lacenObject <- lacenBootstrap(
                lacenObject = values$lacenObject,
                numberOfIterations = 100,
                maxBlockSize = 50000,
                csvPath = bootstrap_csv_path,
                pathModGroupsPlot = mod_groups_plot_path,
                pathStabilityPlot = stability_plot_path
            )

            output$bootstrap_plots_output <- renderUI({
                list(
                    tags$h4("Bootstrap Results"),
                    tags$a(href = file.path("users_data", values$user_id, "moduleGroups.png"), target = "_blank",
                           tags$img(src = file.path("users_data", values$user_id, "moduleGroups.png"), style = "max-width: 100%; height: auto;")),
                    tags$a(href = file.path("users_data", values$user_id, "moduleStability.png"), target = "_blank",
                           tags$img(src = file.path("users_data", values$user_id, "moduleStability.png"), style = "max-width: 100%; height: auto;"))
                )
            })
            shinyjs::show("bootstrap_threshold_div")

        }, error = function(e) {
            showNotification(paste("Error during bootstrap analysis:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    observeEvent(input$skip_bootstrap_btn, {
        updateNavbarPage(session, "main_nav", selected = "summarize_enrich")
    })

    observeEvent(input$set_bootstrap_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject)
            values$lacenObject <- setBootstrap(lacenObject = values$lacenObject, cutBootstrap = input$bootstrap_threshold_input)
            updateNavbarPage(session, "main_nav", selected = "summarize_enrich")
        }, error = function(e) {
            showNotification(paste("Error after setting bootstrap:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    observeEvent(input$run_summarize_enrich_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            scientific_name <- c(
                "Homo sapiens", "Mus musculus", "Rattus norvegicus", "Danio rerio",
                "Drosophila melanogaster", "Caenorhabditis elegans", "Saccharomyces cerevisiae",
                "Arabidopsis thaliana", "Gallus gallus", "Sus scrofa", "Bos taurus",
                "Canis familiaris")

            gprofiler_code <- c(
                "hsapiens", "mmusculus", "rnorvegicus", "drerio", "dmelanogaster", "celegans",
                "scerevisiae", "athaliana", "ggallus", "sscrofa", "btaurus",
                "cfamiliaris")

            orgdb_package <- c(
                "org.Hs.eg.db", "org.Mm.eg.db", "org.Rn.eg.db", "org.Dr.eg.db", "org.Dm.eg.db",
                "org.Ce.eg.db", "org.Sc.sgd.db", "org.At.tair.db", "org.Gg.eg.db", "org.Ss.eg.db",
                "org.Bt.eg.db", "org.Cf.eg.db")

            user_organism_index <- which(input$organism == scientific_name)
            values$organism <- gprofiler_code[user_organism_index]
            values$orgdb <- orgdb_package[user_organism_index]

            if (!require(values$orgdb, quietly = TRUE, character.only = TRUE))
                BiocManager::install(values$orgdb)

            enriched_path <- file.path("users", values$user_id, "enrichedgraph.png")
            stacked_path <- file.path("users", values$user_id, "stackedplot.png")
            mod_path <- file.path("users", values$user_id)
            log_path <- file.path("users", values$user_id, "log.txt")
            values$lacenObject <- summarizeAndEnrichModules(values$lacenObject,
                                                                maxBlockSize = 20000,
                                                                filename = enriched_path,
                                                                modPath = mod_path,
                                                                log = TRUE,
                                                                log_path = log_path,
                                                                organism = values$organism,
                                                                orgdb = values$orgdb)
            stackedBarplot(values$lacenObject, filename = stacked_path, plot = FALSE)
            saveRDS(values$lacenObject, file.path("users", values$user_id, "lacenObject.rds"))
            output$enriched_graph_output <- renderUI({ tags$a(href = file.path("users_data", values$user_id, "enrichedgraph.png"), target = "_blank", tags$img(src = file.path("users_data", values$user_id, "enrichedgraph.png"), style = "max-width: 100%; height: auto;")) })
            output$stacked_barplot_output <- renderUI({ tags$a(href = file.path("users_data", values$user_id, "stackedplot.png"), target = "_blank", tags$img(src = file.path("users_data", values$user_id, "stackedplot.png"), style = "max-width: 100%; height: auto;")) })
        }, error = function(e) {
            showNotification(paste("Error during Summarize/Enrich:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # 6.0 Heatmap
    observeEvent(input$run_heatmap_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject)
            submodule_val <- if (input$submodule_input == 0) FALSE else input$submodule_input
            
            test_module <- function(module, submodule, summdf){
                suppressWarnings(sel_modules <- (names(summdf) == "module" | !is.na(as.numeric(names(summdf)))))
                valid_modules <- summdf[, sel_modules] %>% group_by(module) %>% summarize(across(everything(), any), .groups = 'drop')
                if(module %in% valid_modules$module){
                    if(isFALSE(submodule)) return(TRUE)
                    submodules <- unlist(valid_modules[valid_modules$module == module, -1])
                    submodules <- as.numeric(names(submodules)[submodules == TRUE])
                    return(submodule %in% submodules)
                }
                return(FALSE)
            }

            if(test_module(input$module_input, submodule_val, values$lacenObject$summdf)){
                if (isFALSE(submodule_val)) {
                    file_name <- file.path("users",
                            values$user_id,
                            paste0("heatmap_", input$module_input, ".png"))
                    out_tsv <- file.path("users",
                            values$user_id,
                            paste0("heatmap_", input$module_input, ".tsv"))
                } else {
                    file_name <- file.path("users",
                            values$user_id,
                            paste0("heatmap_", input$module_input, "_", submodule_val, ".png"))
                    out_tsv <- file.path("users",
                            values$user_id,
                            paste0("heatmap_", input$module_input, "_", submodule_val, ".tsv"))
                }
                heatmapTopConnectivity(values$lacenObject,
                            module = input$module_input,
                            submodule = submodule_val,
                            filename = file_name,
                            outTSV = out_tsv)
                output$heatmap_plot <- renderUI({
                    tags$a(href = file.path("users_data", values$user_id, basename(file_name)), target = "_blank",
                           tags$img(src = file.path("users_data", values$user_id, basename(file_name)), style = "max-width: 100%; height: auto;"))
                })
            } else {
                showNotification("Invalid module/submodule. See the last plot for reference.", type = "error")
            }
        }, error = function(e) {
            showNotification(paste("Heatmap generation failed:", e$message), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
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
        session$sendCustomMessage(type = 'show_overlay', message = list())
        tryCatch({
            req(values$lacenObject, input$lncSymbol_input)
            net_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_netPlot.png"))
            enr_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_enrPlot.png"))
            connec_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_connectivities.csv"))
            enr_csv_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_enrichment.csv"))
            
            lncRNAEnrich(
                lncName = input$lncSymbol_input, lacenObject = values$lacenObject,
                nGenesNet = input$nGenesNet_input, nTerm = input$nTerm_input, nGenes = input$nGenes_input,
                sources = input$sources_input, netPath = net_path, enrPath = enr_path,
                connecPath = connec_path, enrCsvPath = enr_csv_path
            )

            image_filename_net <- paste0(input$lncSymbol_input, "_netPlot.png")
            image_filename_enr <- paste0(input$lncSymbol_input, "_enrPlot.png")
            output$lnc_net_plot_output <- renderUI({ tags$a(href = file.path("users_data", values$user_id, image_filename_net), target = "_blank", tags$img(src = file.path("users_data", values$user_id, image_filename_net), style = "max-width: 100%; height: auto;")) })
            output$lnc_enr_plot_output <- renderUI({ tags$a(href = file.path("users_data", values$user_id, image_filename_enr), target = "_blank", tags$img(src = file.path("users_data", values$user_id, image_filename_enr), style = "max-width: 100%; height: auto;")) })
        }, error = function(e) {
            showNotification(paste("LNC-centric analysis failed: Please try to increase the nGenes or try another lncRNA"), type = "error", duration = NULL)
        }, finally = {
            session$sendCustomMessage(type = 'hide_overlay', message = list())
        })
    })

    # 8.0 Download Data
    output$download_data_btn <- downloadHandler(
        filename = function() { "lacen_pipeline_results.zip" },
        content = function(file) {
            temp_zip_dir <- tempdir()
            final_output_folder <- file.path(temp_zip_dir, "lacen_output")
            dir.create(final_output_folder, recursive = TRUE)
            all_user_files <- list.files(file.path("users", values$user_id), full.names = TRUE)
            all_user_files <- all_user_files[!grepl("*.rds", all_user_files)]
            file.copy(all_user_files, file.path(final_output_folder, basename(all_user_files)))
            old_wd <- setwd(temp_zip_dir)
            on.exit(setwd(old_wd))
            utils::zip(zipfile = file, files = "lacen_output")
        }
    )
}

# Run the application
shinyApp(ui = ui, server = server)