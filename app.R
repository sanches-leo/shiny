library(shiny)
library(shinyjs)
library(lacen)
library(dplyr)
library(future)
library(promises)

plan(multisession)

options(shiny.launch.browser = TRUE)
options(shiny.maxRequestSize = 100 * 1024^2)
options(shiny.port = 3838)

maxBlockSize <- 20000
nThreads <- 4



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
          fluidRow(
              br(),  # Adds a vertical space
              column(2,              
                  wellPanel(
                      h4("User Login"),
                      textInput("user_id", "Enter User ID:"),
                      passwordInput("password", "Enter Password:"),
                      actionButton("login_btn", "Login"),
                      textOutput("login_message")
                  )
              ),
              column(10,
                  includeMarkdown("docs/wellcome.md")
              )
          )
      )
  ),
  div(id = "main_app", style = "display: none;",
      navbarPage(
        "LACEN Pipeline",
        id = "main_nav",
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
                     sidebarPanel(width = 3,
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
                     sidebarPanel(width = 3,
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
                   sidebarLayout(
                     sidebarPanel(width = 3,
                       p("This step is optional and can be very time-consuming (from hours to days). It remakes the network multiple times to find the most robust modules."),
                       hr(),
                       actionButton("run_bootstrap_btn", "Run Bootstrap Analysis"),
                       actionButton("skip_bootstrap_btn", "Skip and Proceed to Summarize/Enrich"),
                       hr(),
                       div(id = "bootstrap_threshold_div", style = "display: none;",
                           numericInput("bootstrap_threshold_input", "Bootstrap Threshold", value = 0.8, min = 0, max = 1, step = 0.05),
                           actionButton("set_bootstrap_btn", "Apply Threshold and Proceed")
                       )
                     ),
                     mainPanel(
                       fluidRow(
                         column(6, uiOutput("bootstrap_plots_output_module")),
                         column(6, uiOutput("bootstrap_plots_output_stability"))
                       )
                     )
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
                     sidebarPanel(width = 3,
                       numericInput("module_input", "Select Module", 1, min = 1),
                       numericInput("submodule_input", "Select Submodule (0 for FALSE)", 0, min = 0),
                       numericInput("hm_dimensions_input", "Heatmap Dimensions (0 for FALSE)", 0),
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
                     sidebarPanel(width = 3,
                       selectizeInput("lncSymbol_input", "LNC Symbol", choices = NULL),
                       numericInput("nGenes_input", "Gene Count for Enrichment", 100),
                       numericInput("nGenesNet_input", "Gene Count for Visualization", 20),
                       numericInput("nTerm_input", "Pathway Count for Plotting", 10),
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
  observeEvent(input$help_load_data, {
    showModal(modalDialog(
      title = "Load Data", includeMarkdown("docs/loadData.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_filter_transform, {
    showModal(modalDialog(
      title = "Filter and Transform", includeMarkdown("docs/filterTransform.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_clustering, {
    showModal(modalDialog(
      title = "Clustering", includeMarkdown("docs/clustering.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_soft_threshold, {
    showModal(modalDialog(
      title = "Soft Threshold", includeMarkdown("docs/softThreshold.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_bootstrap, {
    showModal(modalDialog(
      title = "Bootstrap", includeMarkdown("docs/bootstrap.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_summarize_enrich, {
    showModal(modalDialog(
      title = "Summarize and Enrich", includeMarkdown("docs/summarizeEnrich.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_heatmap, {
    showModal(modalDialog(
      title = "Heatmap", includeMarkdown("docs/heatmap.md"),
      easyClose = TRUE, footer = NULL
    ))
  })
  observeEvent(input$help_lnc_centric, {
    showModal(modalDialog(
      title = "LNC-centric Analysis", includeMarkdown("docs/lncCentric.md"),
      easyClose = TRUE, footer = NULL
    ))
  })

  # Reactive values to store data and state
  values <- reactiveValues(
    lacenObject = NULL, data_checked = FALSE,
    lncList = NULL, user_id = NULL
  )

  # Login screen logic
  observeEvent(input$login_btn, {
    user_id <- trimws(input$user_id)
    password <- input$password
    
    if (user_id == "" || password == "") {
      output$login_message <- renderText({ "User ID and password cannot be empty." })
      return()
    }
    
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    future({
      correct_password <- trimws(readLines(".pass", n = 1))
      if (password != correct_password) {
        return(list(status = "fail", message = "Incorrect password."))
      }
      
      user_dir <- file.path("www", "users", user_id)
      if (!dir.exists(user_dir)) dir.create(user_dir, recursive = TRUE)
      
      lacen_object_path <- file.path("www", "users", user_id, "lacenObject.rds")
      if (file.exists(lacen_object_path)) {
        return(list(status = "load_session", user_id = user_id))
      } else {
        return(list(status = "new_session", user_id = user_id))
      }
    }) %...>% (function(result) {
      if (result$status == "fail") {
        output$login_message <- renderText({ result$message })
      } else {
        values$user_id <- result$user_id
        if (result$status == "load_session") {
          lacen_object_path <- file.path("www", "users", values$user_id, "lacenObject.rds")
          values$lacenObject <- readRDS(lacen_object_path)

          # Regenerate plots (this part is fast UI rendering, no future needed here)
          cluster_tree_path_threshold <- file.path("www", "users", values$user_id, "clusterTreeThreshold.png")
          cluster_tree_path_initial <- file.path("www", "users", values$user_id, "clusterTree.png")
          final_cluster_path <- if (file.exists(cluster_tree_path_threshold)) {
            file.path("users", values$user_id, "clusterTreeThreshold.png")
          } else if (file.exists(cluster_tree_path_initial)) {
            file.path("users", values$user_id, "clusterTree.png")
          }
          if (!is.null(final_cluster_path)) {
            output$cluster_tree_plot <- renderUI({ tags$a(href = final_cluster_path, target = "_blank", tags$img(src = final_cluster_path, style = "max-width: 100%; height: auto;")) })
          }

          soft_threshold_path_file <- file.path("www", "users", values$user_id, "indicePower.png")
          if (file.exists(soft_threshold_path_file)) {
            output$soft_threshold_plot <- renderUI({ tags$a(href = file.path("users", values$user_id, "indicePower.png"), target = "_blank", tags$img(src = file.path("users", values$user_id, "indicePower.png"), style = "max-width: 100%; height: auto;")) })
          }

          mod_groups_plot_path <- file.path("www", "users", values$user_id, "moduleGroups.png")
          stability_plot_path <- file.path("www", "users", values$user_id, "moduleStability.png")
          if (file.exists(mod_groups_plot_path) && file.exists(stability_plot_path)) {
            output$bootstrap_plots_output_module <- renderUI({ tags$a(href = file.path("users", values$user_id, "moduleGroups.png"), target = "_blank", tags$img(src = file.path("users", values$user_id, "moduleGroups.png"), style = "max-width: 100%; height: auto;")) })
            output$bootstrap_plots_output_stability <- renderUI({ tags$a(href = file.path("users", values$user_id, "moduleStability.png"), target = "_blank", tags$img(src = file.path("users", values$user_id, "moduleStability.png"), style = "max-width: 100%; height: auto;")) })
            shinyjs::show("bootstrap_threshold_div")
          }

          enriched_graph_path_file <- file.path("www", "users", values$user_id, "enrichedgraph.png")
          if (file.exists(enriched_graph_path_file)) {
            output$enriched_graph_output <- renderUI({ tags$a(href = file.path("users", values$user_id, "enrichedgraph.png"), target = "_blank", tags$img(src = file.path("users", values$user_id, "enrichedgraph.png"), style = "max-width: 100%; height: auto;")) })
          }
          stacked_barplot_path_file <- file.path("www", "users", values$user_id, "stackedplot.png")
          if (file.exists(stacked_barplot_path_file)) {
            output$stacked_barplot_output <- renderUI({ tags$a(href = file.path("users", values$user_id, "stackedplot.png"), target = "_blank", tags$img(src = file.path("users", values$user_id, "stackedplot.png"), style = "max-width: 100%; height: auto;")) })
          }
          
          shinyjs::hide("login_screen")
          shinyjs::show("main_app")
          updateNavbarPage(session, "main_nav", selected = "heatmap")
        } else { # New Session
          shinyjs::hide("login_screen")
          shinyjs::show("main_app")
          updateNavbarPage(session, "main_nav", selected = "load_data")
        }
      }
    }) %...!% (function(error) {
      output$login_message <- renderText({ paste("An error occurred:", error$message) })
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
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
    future({
      data("annotation_data", "expression_DGE", "nc_annotation", "raw_expression", "traits")
      initLacen(
        annotationData = annotation_data, datCounts = raw_expression,
        datExpression = expression_DGE, datTraits = traits,
        ncAnnotation = nc_annotation
      )
    }) %...>% (function(new_lacen_object) {
      values$lacenObject <- new_lacen_object
      output$check_data_output <- renderPrint({ "Demo data loaded. Click 'Check Data Format'." })
      updateActionButton(session, "check_data_btn", disabled = FALSE)
    }) %...!% (function(error) {
      showNotification(paste("Error loading demo data:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  check_output_text <- reactiveVal("Data has not been checked yet.")
  output$check_data_output <- renderPrint({ cat(check_output_text()) })
  
  observeEvent(input$check_data_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    file_inputs <- list(
      annotationData = input$annotationData_file,
      expressionDGEData = input$expressionDGEData_file,
      ncAnnotation = input$ncAnnotation_file,
      rawExpressionData = input$rawExpressionData_file,
      traitsData = input$traitsData_file
    )
    
    future({
      lacen_object_to_check <- current_lacen_object
      if (is.null(lacen_object_to_check)) {
        req(file_inputs$annotationData, file_inputs$expressionDGEData, file_inputs$ncAnnotation, file_inputs$rawExpressionData, file_inputs$traitsData)
        expressionDGEData <- read.csv(file_inputs$expressionDGEData$datapath)
        rawExpressionData <- read.csv(file_inputs$rawExpressionData$datapath, row.names = 1, check.names = FALSE)
        traitsData <- read.csv(file_inputs$traitsData$datapath)
        ann_ext <- tolower(sub(".*\\.", "", file_inputs$annotationData$name))
        annotationData <- if (ann_ext == "csv") read.csv(file_inputs$annotationData$datapath) else loadGTF(file_inputs$annotationData$datapath)
        ncann_ext <- tolower(sub(".*\\.", "", file_inputs$ncAnnotation$name))
        ncAnnotation <- if (ncann_ext == "csv") read.csv(file_inputs$ncAnnotation$datapath) else loadGTF(file_inputs$ncAnnotation$datapath)
        
        lacen_object_to_check <- initLacen(
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
      list(
        result = check_result, warnings = warnings_captured,
        new_object = lacen_object_to_check
      )
    }) %...>% (function(res) {
      values$lacenObject <- res$new_object
      if (isTRUE(res$result)) {
        values$data_checked <- TRUE
        check_output_text("Data check passed! Proceeding to the next step.")
        updateNavbarPage(session, "main_nav", selected = "filter_transform")
      } else {
        check_output_text(paste(res$warnings, collapse = "\n"))
      }
    }) %...!% (function(error) {
      check_output_text(paste("An error occurred during data check:", error$message))
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$run_filter_transform_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    pThreshold <- input$pThreshold
    fcThreshold <- input$fcThreshold
    filterMethod <- input$filterMethod
    topVarGenes <- input$topVarGenes
    user_id <- values$user_id
    
    future({
      req(current_lacen_object, pThreshold, fcThreshold, filterMethod, topVarGenes, user_id)
      
      if (filterMethod == "DEG") {
        new_lacen_object <- filterTransform(current_lacen_object, pThreshold = pThreshold, fcThreshold = fcThreshold, filterMethod = "DEG")
      } else {
        new_lacen_object <- filterTransform(current_lacen_object, topVarGenes = topVarGenes, filterMethod = "var")
      }
      
      file_name <- file.path("www", "users", user_id, "clusterTree.png")
      selectOutlierSample(new_lacen_object, height = FALSE, plot = FALSE, filename = file_name)
      
      list(new_object = new_lacen_object, plot_file = file_name)
    }) %...>% (function(result) {
      values$lacenObject <- result$new_object
      output$filter_transform_output <- renderPrint({ "Filter and transform complete. Proceeding to clustering." })
      updateNavbarPage(session, "main_nav", selected = "clustering")
      output$cluster_tree_plot <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(result$plot_file)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(result$plot_file)), style = "max-width: 100%; height: auto;"))
      })
    }) %...!% (function(error) {
      showNotification(paste("Error during Filter/Transform:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$rerun_clustering_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    height_input <- input$height_input
    user_id <- values$user_id
    
    future({
      req(current_lacen_object, user_id)
      height_val <- if (height_input == 0) FALSE else height_input
      file_name <- file.path("www", "users", user_id, paste0("clusterTree_Threshold_", height_val, ".png"))
      selectOutlierSample(current_lacen_object, height = height_val, plot = FALSE, filename = file_name)
      return(file_name)
    }) %...>% (function(plot_file) {
      output$cluster_tree_plot <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(plot_file)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(plot_file)), style = "max-width: 100%; height: auto;"))
      })
    }) %...!% (function(error) {
      showNotification(paste("Error during clustering:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$accept_height_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    height_input <- input$height_input
    user_id <- values$user_id
    
    future({
      req(current_lacen_object, user_id)
      height_val <- if (height_input == 0) FALSE else height_input
      new_lacen_object <- cutOutlierSample(current_lacen_object, height = height_val)
      
      file_name <- file.path("www", "users", user_id, "indicePower.png")
      plotSoftThreshold(new_lacen_object, filename = file_name, maxBlockSize = maxBlockSize, plot = FALSE)
      
      list(new_object = new_lacen_object, plot_file = file_name)
    }) %...>% (function(result) {
      values$lacenObject <- result$new_object
      updateNavbarPage(session, "main_nav", selected = "soft_threshold")
      output$soft_threshold_plot <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(result$plot_file)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(result$plot_file)), style = "max-width: 100%; height: auto;"))
      })
    }) %...!% (function(error) {
      showNotification(paste("Error accepting height:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$run_soft_threshold_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    indicePower_input <- input$indicePower_input
    
    future({
      req(current_lacen_object)
      selectSoftThreshold(current_lacen_object, indicePower = indicePower_input)
    }) %...>% (function(new_lacen_object) {
      values$lacenObject <- new_lacen_object
      updateNavbarPage(session, "main_nav", selected = "bootstrap")
    }) %...!% (function(error) {
      showNotification(paste("Error during soft threshold selection:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$run_bootstrap_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    showNotification("Running bootstrap analysis. This may take a very long time.", type = "warning", duration = NULL)
    
    current_lacen_object <- values$lacenObject
    user_id <- values$user_id
    
    future({
      req(current_lacen_object, user_id)
      bootstrap_csv_path <- file.path("www", "users", user_id, "bootstrap.csv")
      mod_groups_plot_path <- file.path("www", "users", user_id, "moduleGroups.png")
      stability_plot_path <- file.path("www", "users", user_id, "moduleStability.png")
      
      new_lacen_object <- lacenBootstrap(
        lacenObject = current_lacen_object, numberOfIterations = 100,
        maxBlockSize = maxBlockSize, csvPath = bootstrap_csv_path,
        pathModGroupsPlot = mod_groups_plot_path,
        pathStabilityPlot = stability_plot_path, nThreads = nThreads
      )
      saveRDS(new_lacen_object, file.path("www", "users", user_id, "lacenObject.rds"))
      
      list(
        new_object = new_lacen_object,
        mod_groups_plot = mod_groups_plot_path,
        stability_plot = stability_plot_path
      )
    }) %...>% (function(result) {
      values$lacenObject <- result$new_object
      output$bootstrap_plots_output_module <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(result$mod_groups_plot)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(result$mod_groups_plot)), style = "max-width: 100%; height: auto;"))
      })
      output$bootstrap_plots_output_stability <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(result$stability_plot)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(result$stability_plot)), style = "max-width: 100%; height: auto;"))
      })
      shinyjs::show("bootstrap_threshold_div")
    }) %...!% (function(error) {
      showNotification(paste("Error during bootstrap analysis:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$skip_bootstrap_btn, {
    updateNavbarPage(session, "main_nav", selected = "summarize_enrich")
  })
  
  observeEvent(input$set_bootstrap_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    bootstrap_threshold_input <- input$bootstrap_threshold_input
    
    future({
      req(current_lacen_object)
      setBootstrap(lacenObject = current_lacen_object, cutBootstrap = bootstrap_threshold_input)
    }) %...>% (function(new_lacen_object) {
      values$lacenObject <- new_lacen_object
      updateNavbarPage(session, "main_nav", selected = "summarize_enrich")
    }) %...!% (function(error) {
      showNotification(paste("Error after setting bootstrap:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$run_summarize_enrich_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    user_id <- values$user_id
    organism_input <- input$organism
    
    future({
      req(current_lacen_object, user_id, organism_input)
      
      scientific_name <- c("Homo sapiens", "Mus musculus", "Rattus norvegicus", "Danio rerio", "Drosophila melanogaster", "Caenorhabditis elegans", "Saccharomyces cerevisiae", "Arabidopsis thaliana", "Gallus gallus", "Sus scrofa", "Bos taurus", "Canis familiaris")
      gprofiler_code <- c("hsapiens", "mmusculus", "rnorvegicus", "drerio", "dmelanogaster", "celegans", "scerevisiae", "athaliana", "ggallus", "sscrofa", "btaurus", "cfamiliaris")
      orgdb_package <- c("org.Hs.eg.db", "org.Mm.eg.db", "org.Rn.eg.db", "org.Dr.eg.db", "org.Dm.eg.db", "org.Ce.eg.db", "org.Sc.sgd.db", "org.At.tair.db", "org.Gg.eg.db", "org.Ss.eg.db", "org.Bt.eg.db", "org.Cf.eg.db")
      
      user_organism_index <- which(organism_input == scientific_name)
      organism <- gprofiler_code[user_organism_index]
      orgdb <- orgdb_package[user_organism_index]
      
      if (!require(orgdb, quietly = TRUE, character.only = TRUE)) BiocManager::install(orgdb)
      
      enriched_path <- file.path("www", "users", user_id, "enrichedgraph.png")
      stacked_path <- file.path("www", "users", user_id, "stackedplot.png")
      
      new_lacen_object <- summarizeAndEnrichModules(
        current_lacen_object, maxBlockSize = maxBlockSize, filename = enriched_path,
        modPath = file.path("www", "users", user_id), log = TRUE,
        log_path = file.path("www", "users", user_id, "log.txt"), organism = organism,
        orgdb = orgdb, pathTSV = file.path("www", "users", user_id, "summary.tsv")
      )
      stackedBarplot(new_lacen_object, filename = stacked_path, plot = FALSE)
      saveRDS(new_lacen_object, file.path("www", "users", user_id, "lacenObject.rds"))
      
      list(
        new_object = new_lacen_object,
        enriched_plot = enriched_path,
        stacked_plot = stacked_path
      )
    }) %...>% (function(result) {
      values$lacenObject <- result$new_object
      output$enriched_graph_output <- renderUI({ tags$a(href = file.path("users", values$user_id, basename(result$enriched_plot)), target = "_blank", tags$img(src = file.path("users", values$user_id, basename(result$enriched_plot)), style = "max-width: 100%; height: auto;")) })
      output$stacked_barplot_output <- renderUI({ tags$a(href = file.path("users", values$user_id, basename(result$stacked_plot)), target = "_blank", tags$img(src = file.path("users", values$user_id, basename(result$stacked_plot)), style = "max-width: 100%; height: auto;")) })
    }) %...!% (function(error) {
      showNotification(paste("Error during Summarize/Enrich:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$run_heatmap_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    user_id <- values$user_id
    module_input <- input$module_input
    submodule_input <- input$submodule_input
    hm_dimensions_input <- input$hm_dimensions_input
    
    future({
      req(current_lacen_object, user_id, module_input)
      submodule_val <- if (submodule_input == 0) FALSE else submodule_input
      
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
      
      if(test_module(module_input, submodule_val, current_lacen_object$summdf)){
        prefix <- if (isFALSE(submodule_val)) {
          paste0("heatmap_", module_input, "_d", hm_dimensions_input)
        } else {
          paste0("heatmap_", module_input, "_", submodule_val, "_d", hm_dimensions_input)
        }
        file_name <- file.path("www", "users", user_id, paste0(prefix, ".png"))
        out_tsv <- file.path("www", "users", user_id, paste0(prefix, ".tsv"))
        hm_dimensions <- if (hm_dimensions_input == 0) FALSE else hm_dimensions_input
        
        heatmapTopConnectivity(
          current_lacen_object, module = module_input, submodule = submodule_val,
          filename = file_name, outTSV = out_tsv, hmDimensions = hm_dimensions
        )
        return(list(status = "success", plot_file = file_name))
      } else {
        return(list(status = "fail", message = "Invalid module/submodule. See the last plot for reference."))
      }
    }) %...>% (function(result) {
      if (result$status == "success") {
        output$heatmap_plot <- renderUI({
          tags$a(href = file.path("users", values$user_id, basename(result$plot_file)), target = "_blank",
                 tags$img(src = file.path("users", values$user_id, basename(result$plot_file)), style = "max-width: 100%; height: auto;"))
        })
      } else {
        showNotification(result$message, type = "error")
      }
    }) %...!% (function(error) {
      showNotification(paste("Heatmap generation failed:", error$message), type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  observeEvent(input$main_nav, {
    if (input$main_nav == "lnc_centric" && !is.null(values$lacenObject)) {
      lncList <- values$lacenObject$summdf$gene_name[values$lacenObject$summdf$is_nc]
      updateSelectizeInput(session, "lncSymbol_input", choices = lncList, server = TRUE)
    }
  })
  
  observeEvent(input$run_lnc_analysis_btn, {
    session$sendCustomMessage(type = 'show_overlay', message = list())
    
    current_lacen_object <- values$lacenObject
    user_id <- values$user_id
    lncSymbol_input <- input$lncSymbol_input
    nGenes_input <- input$nGenes_input
    nGenesNet_input <- input$nGenesNet_input
    nTerm_input <- input$nTerm_input
    sources_input <- input$sources_input
    
    future({
      req(current_lacen_object, user_id, lncSymbol_input)
      base_filename <- paste(lncSymbol_input, nGenes_input, nGenesNet_input, nTerm_input, sources_input, sep = "_")
      net_path <- file.path("www", "users", user_id, paste0(base_filename, "_netPlot.png"))
      enr_path <- file.path("www", "users", user_id, paste0(base_filename, "_enrPlot.png"))
      
      lncRNAEnrich(
        lncName = lncSymbol_input, lacenObject = current_lacen_object,
        nGenesNet = nGenesNet_input, nTerm = nTerm_input, nGenes = nGenes_input,
        sources = sources_input, netPath = net_path, enrPath = enr_path,
        connecPath = file.path("www", "users", user_id, paste0(base_filename, "_connectivities.csv")),
        enrCsvPath = file.path("www", "users", user_id, paste0(base_filename, "_enrichment.csv"))
      )
      list(net_plot = net_path, enr_plot = enr_path)
    }) %...>% (function(result) {
      output$lnc_net_plot_output <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(result$net_plot)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(result$net_plot)), style = "max-width: 100%; height: auto;"))
      })
      output$lnc_enr_plot_output <- renderUI({
        tags$a(href = file.path("users", values$user_id, basename(result$enr_plot)), target = "_blank",
               tags$img(src = file.path("users", values$user_id, basename(result$enr_plot)), style = "max-width: 100%; height: auto;"))
      })
    }) %...!% (function(error) {
      showNotification("LNC-centric analysis failed: Please try to increase the nGenes or try another lncRNA", type = "error", duration = NULL)
    }) %>%
    finally(~{
      session$sendCustomMessage(type = 'hide_overlay', message = list())
    })
    return(NULL)
  })
  
  output$download_data_btn <- downloadHandler(
    filename = function() { "lacen_pipeline_results.zip" },
    content = function(file) {
      temp_zip_dir <- tempdir()
      final_output_folder <- file.path(temp_zip_dir, "lacen_output")
      dir.create(final_output_folder, recursive = TRUE)
      
      all_user_files <- list.files(file.path("www", "users", values$user_id), full.names = TRUE)
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
