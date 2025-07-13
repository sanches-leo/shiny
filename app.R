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
                            uiOutput("cluster_tree_plot")
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
                            uiOutput("soft_threshold_plot")
                        )
                    )
                )
            ),
            tabPanel("Summarize and Enrich",
                value = "summarize_enrich",
                fluidPage(
                    titlePanel("Summarize and Enrich Modules"),
                    fluidRow(
                    column(6, uiOutput("enriched_graph_output")),
                    column(6, uiOutput("stacked_barplot_output"))
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
                            uiOutput("heatmap_plot")
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
    # Reactive values to store data and state
    values <- reactiveValues(
        lacenObject = NULL,
        data_checked = FALSE,
        lncList = NULL,
        user_id = NULL
    )

    # Reactive observer to regenerate plots when lacenObject is loaded from a saved session
    observe({
        req(values$lacenObject)
        # Check if we are in a restored session by looking at the selected tab
        if (input$main_nav == "heatmap") {

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
        session$sendCustomMessage(type = 'show_overlay', message = list()) # Show overlay
        user_id <- trimws(input$user_id)
        password <- input$password

        # Read password from .pass file
        correct_password <- trimws(readLines(".pass", n = 1))

        if (user_id == "" || password == "") {
            output$login_message <- renderText({
                "User ID and password cannot be empty."
            })
            session$sendCustomMessage(type = 'hide_overlay', message = list()) # Hide overlay on error
        } else if (password != correct_password) {
            output$login_message <- renderText({
                "Incorrect password."
            })
            session$sendCustomMessage(type = 'hide_overlay', message = list()) # Hide overlay on error
        } else {
            user_dir <- file.path("users", user_id)
            if (!dir.exists(user_dir)) {
                dir.create(user_dir, recursive = TRUE)
            }
            addResourcePath("users_data", "users") # Map 'users' directory to '/users_data' URL
            values$user_id <- user_id

            # Check if lacenObject.rds exists for this user
            lacen_object_path <- file.path("users", values$user_id, "lacenObject.rds")
            if (file.exists(lacen_object_path)) {
                values$lacenObject <- readRDS(lacen_object_path)
                shinyjs::hide("login_screen")
                shinyjs::show("main_app")
                updateNavbarPage(session, "main_nav", selected = "heatmap") # Skip to Heatmap tab
            } else {
                shinyjs::hide("login_screen")
                shinyjs::show("main_app")
            }
            session$sendCustomMessage(type = 'hide_overlay', message = list()) # Hide overlay after successful login
        }
    })

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
        session$sendCustomMessage(type = 'show_overlay', message = list())
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
        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    # 1. Create a reactiveVal to store the output text. This is the correct way.
    check_output_text <- reactiveVal("Data has not been checked yet.")

    # 2. Your renderPrint should be defined ONCE, outside the observer.
    #    It simply displays the content of the reactiveVal.
    output$check_data_output <- renderPrint({
        cat(check_output_text())
    })

    # 3. The observeEvent handles the logic when the button is clicked.
    observeEvent(input$check_data_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        
        # Use a temporary variable to hold the object we are going to check
        lacen_object_to_check <- NULL

        # --- Logic to load or retrieve the data ---
        if (!is.null(values$lacenObject)) { 
            # Path 1: Demo data already exists
            lacen_object_to_check <- values$lacenObject
        } else { 
            # Path 2: Load data from file uploads
            req(
                input$annotationData_file,
                input$expressionDGEData_file,
                input$ncAnnotation_file,
                input$rawExpressionData_file,
                input$traitsData_file
            )

            # Use a tryCatch to handle potential errors during file reading
            tryCatch({
                expressionDGEData <- read.csv(input$expressionDGEData_file$datapath)
                rawExpressionData <- read.csv(input$rawExpressionData_file$datapath)
                traitsData <- read.csv(input$traitsData_file$datapath)

                # --- Correctly read annotationData ---
                ann_filename <- input$annotationData_file$name
                ann_ext <- tolower(sub(".*\\.", "", ann_filename))
                if (ann_ext == "csv") {
                    annotationData <- read.csv(input$annotationData_file$datapath)
                } else {
                    annotationData <- loadGTF(input$annotationData_file$datapath)
                }

                # --- Correctly read ncAnnotation (FIXED BUG) ---
                ncann_filename <- input$ncAnnotation_file$name
                ncann_ext <- tolower(sub(".*\\.", "", ncann_filename))
                if (ncann_ext == "csv") {
                    ncAnnotation <- read.csv(input$ncAnnotation_file$datapath)
                } else {
                    ncAnnotation <- loadGTF(input$ncAnnotation_file$datapath)
                }

                # Initialize the object and assign it to our temporary variable
                lacen_object_to_check <- initLacen(
                    annotationData = annotationData,
                    datCounts = rawExpressionData,
                    datExpression = expressionDGEData,
                    datTraits = traitsData,
                    ncAnnotation = ncAnnotation
                )
                # Also store it in reactive values for future use
                values$lacenObject <- lacen_object_to_check
            }, error = function(e) {
                # If any file reading fails, show an error and stop
                check_output_text(paste("Error reading files:", e$message))
                session$sendCustomMessage(type = 'hide_overlay', message = list())
                return() # Stop execution
            })
        }

        # --- Unified Check Logic (runs for both demo and uploaded data) ---
        warnings_captured <- c()
        if (!is.null(lacen_object_to_check)) {
            check_result <- FALSE # Default to failure
            # Capture the printed output AND the return value of the function
            check_result <- withCallingHandlers({
                checkData(values$lacenObject)
            }, warning = function(w) {
                warnings_captured <<- c(warnings_captured, w$message)
                invokeRestart("muffleWarning")
            })

            # Now, check the result
            if (isTRUE(check_result)) {
                values$data_checked <- TRUE
                check_output_text("Data check passed! Proceeding to the next step.")
                updateNavbarPage(session, "main_nav", selected = "filter_transform")
            } else {
                # If the check fails, display the captured error/warning messages
                final_warning_text <- paste(warnings_captured, collapse = "\n")
                check_output_text(final_warning_text)
            }
        }
        
        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    # 3.0 Filter and Transform
    observeEvent(input$run_filter_transform_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
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
        file_name <- file.path("users", values$user_id, "clusterTree.png")

        selectOutlierSample(values$lacenObject,
                            height = FALSE,
                            plot = FALSE,
                            filename = file_name)

        output$cluster_tree_plot <- renderUI({
            tags$a(
                href = file.path("users_data", values$user_id, "clusterTree.png"), target = "_blank",
                tags$img(src = file.path("users_data", values$user_id, "clusterTree.png"), style = "max-width: 100%; height: auto;")
            )
        })
        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    # 4.0 Clustering
    observeEvent(input$rerun_clustering_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        req(values$lacenObject)
        height_val <- if (input$height_input == 0) FALSE else input$height_input
        file_name <- file.path("users", values$user_id, "clusterTreeThreshold.png")
        selectOutlierSample(values$lacenObject,
                            height = height_val,
                            plot = FALSE,
                            filename = file_name)

        output$cluster_tree_plot <- renderUI({
            tags$a(
                href = file.path("users_data", values$user_id, "clusterTreeThreshold.png"), target = "_blank",
                tags$img(src = file.path("users_data", values$user_id, "clusterTreeThreshold.png"), style = "max-width: 100%; height: auto;")
            )
        })
        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    observeEvent(input$accept_height_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        req(values$lacenObject)
        height_val <- if (input$height_input == 0) FALSE else input$height_input
        values$lacenObject <- cutOutlierSample(values$lacenObject, height = height_val)
        updateNavbarPage(session, "main_nav", selected = "soft_threshold")
        file_name <- file.path("users", values$user_id, "indicePower.png")

        # Initial soft threshold plot
        plotSoftThreshold(values$lacenObject,
            filename = file_name,
            maxBlockSize = 20000,
            plot = FALSE)

           
        output$soft_threshold_plot <- renderUI({
            tags$a(
                href = file.path("users_data", values$user_id, "indicePower.png"), target = "_blank",
                tags$img(src = file.path("users_data", values$user_id, "indicePower.png"), style = "max-width: 100%; height: auto;")
            )
        })
        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    # 5.0 Soft Threshold
    observeEvent(input$run_soft_threshold_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        req(values$lacenObject)

        values$lacenObject <- selectSoftThreshold(
            lacenObject = values$lacenObject,
            indicePower = input$indicePower_input
        )

        updateNavbarPage(session, "main_nav", selected = "summarize_enrich")

        # Save high-res images to the www directory
        enriched_path <- file.path("users", values$user_id, "enrichedgraph.png")
        stacked_path <- file.path("users", values$user_id, "stackedplot.png")
        mod_path <- file.path("users", values$user_id)
        log_path <- file.path("users", values$user_id, "log.txt")

        values$lacenObject <- summarizeAndEnrichModules(
            lacenObject = values$lacenObject,
            maxBlockSize = 20000,
            filename = enriched_path,
            modPath = mod_path,
            log = TRUE,
            log_path = log_path
        )

        stackedBarplot(
            values$lacenObject,
            filename = stacked_path,
            plot = FALSE
        )

        # Save lacenObject to RDS
        saveRDS(values$lacenObject, file.path("users", values$user_id, "lacenObject.rds"))

        output$enriched_graph_output <- renderUI({
            tags$a(
                href = file.path("users_data", values$user_id, "enrichedgraph.png"), target = "_blank",
                tags$img(src = file.path("users_data", values$user_id, "enrichedgraph.png"), style = "max-width: 100%; height: auto;")
            )
        })

        output$stacked_barplot_output <- renderUI({
            tags$a(
                href = file.path("users_data", values$user_id, "stackedplot.png"), target = "_blank",
                tags$img(src = file.path("users_data", values$user_id, "stackedplot.png"), style = "max-width: 100%; height: auto;")
            )
        })
        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    # 6.0 Heatmap
    observeEvent(input$run_heatmap_btn, {
        session$sendCustomMessage(type = 'show_overlay', message = list())
        req(values$lacenObject)
        submodule_val <- if (input$submodule_input == 0) FALSE else input$submodule_input
        file_name <- file.path("users", values$user_id, paste("heatmap_", input$module_input, ".png", sep = ""))
        out_tsv <- file.path("users", values$user_id, paste("heatmap_", input$module_input, ".tsv", sep = ""))
        image_file_name <- paste("heatmap_", input$module_input, ".png", sep = "")

        test_module <- function(module, submodule, summdf){
            suppressWarnings(
                sel_modules <- (names(summdf) == "module" | !is.na(as.numeric(names(summdf))))
            )
            valid_modules <- summdf[, sel_modules]
            valid_modules <- valid_modules %>% 
                group_by(module) %>%
                summarize(across(everything(), any), .groups = 'drop')
            if(module %in% valid_modules$module){
                if(isFALSE(submodule)){
                return(TRUE)
                } else {
                submodules <- unlist(valid_modules[valid_modules$module == module, -1])
                submodules <- as.numeric(names(submodules)[submodules == TRUE])
                return((module %in% valid_modules$module) & (submodule %in% submodules))
                }
            }

            return(FALSE)
        }

        if(test_module(input$module_input, submodule_val, values$lacenObject$summdf)){
            tryCatch({
                heatmapTopConnectivity(
                    lacenObject = values$lacenObject,
                    module = input$module_input,
                    submodule = submodule_val,
                    filename = file_name,
                    outTSV = out_tsv
                )

                output$heatmap_plot <- renderUI({
                    tags$a(
                        href = file.path("users_data", values$user_id, image_file_name), target = "_blank",
                        tags$img(
                            src = file.path("users_data", values$user_id, image_file_name),
                            style = "max-width: 100%; height: auto;"
                        )
                    )
                })
            }, error = function(e) {
                showNotification(
                    paste("Heatmap generation failed: low connectivity module"),
                    type = "error", duration = NULL
                )
            })
        } else {
            showNotification("Invalid module/submodule. See the last plot for reference.", type = "error")
        }

        session$sendCustomMessage(type = 'hide_overlay', message = list())
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
        req(values$lacenObject, input$lncSymbol_input)
        # Save high-res images to the www directory
        net_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_netPlot.png"))
        enr_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_enrPlot.png"))
        connec_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_connectivities.csv"))
        enr_csv_path <- file.path("users", values$user_id, paste0(input$lncSymbol_input, "_enrichment.csv"))
        image_filename_net <- paste0(input$lncSymbol_input, "_netPlot.png")
        image_filename_enr <- paste0(input$lncSymbol_input, "_enrPlot.png")


        tryCatch({
            lncRNAEnrich(
                lncName = input$lncSymbol_input,
                lacenObject = values$lacenObject,
                nGenesNet = input$nGenesNet_input,
                nTerm = input$nTerm_input,
                nGenes = input$nGenes_input,
                sources = input$sources_input,
                netPath = net_path,
                enrPath = enr_path,
                connecPath = connec_path,
                enrCsvPath = enr_csv_path
        )

            output$lnc_net_plot_output <- renderUI({
                tags$a(
                    href = file.path("users_data", values$user_id, image_filename_net), target = "_blank",
                    tags$img(src = file.path("users_data", values$user_id, image_filename_net), style = "max-width: 100%; height: auto;")
                )
            })

            output$lnc_enr_plot_output <- renderUI({
                tags$a(
                    href = file.path("users_data", values$user_id, image_filename_enr), target = "_blank",
                    tags$img(src = file.path("users_data", values$user_id, image_filename_enr), style = "max-width: 100%; height: auto;")
                )
            })
        }, error = function(e) {
            showNotification(
                paste("No enrichment results. Please increase nGenes number or try another lncRNA."),
                type = "error", duration = NULL
            )
        })

        session$sendCustomMessage(type = 'hide_overlay', message = list())
    })

    # 8.0 Download Data
    output$download_data_btn <- downloadHandler(
        filename = function() {
            "lacen_pipeline_results.zip"
        },
        content = function(file) {
            # Create a temporary directory
            temp_zip_dir <- tempdir()
            # Create the desired output directory structure within the temp directory
            final_output_folder <- file.path(temp_zip_dir, "lacen_output")
            dir.create(final_output_folder, recursive = TRUE)

            # List all files in the user's directory
            all_user_files <- list.files(file.path("users", values$user_id), full.names = TRUE)
            all_user_files <- all_user_files[!grepl("*.rds", all_user_files)]
            files_to_copy <- all_user_files

            # Copy each desired file to the new structure
            for (f in files_to_copy) {
                file.copy(f, file.path(final_output_folder, basename(f)))
            }

            # Zip the contents of the temporary directory.
            # The 'root' argument here is crucial: it makes the paths in the zip relative to temp_zip_dir.
            # So, 'temp_zip_dir/lacen_output/file.png' becomes 'lacen_output/file.png' in the zip.
            # Change working directory to the temporary directory to ensure correct zipping structure
            old_wd <- setwd(temp_zip_dir)
            on.exit(setwd(old_wd)) # Ensure we revert the working directory

            # Zip the 'lacen_output' folder. The 'files' argument should be the folder name relative to the current WD.
            utils::zip(zipfile = file, files = "lacen_output")
        }
    )
}

# Run the application
shinyApp(ui = ui, server = server)