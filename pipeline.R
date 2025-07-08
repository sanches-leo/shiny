# This is the instructions to wrap lacen pipeline in a shiny app. Each topic is a new screen in the app.

# 1.0 Greetings to lacen

library(lacen)
library(dplyr)

# 2.0 Loading Data
# The user should be able to update their data or use demo data using data function
# Create a input camp to upload a tsv file for annotationData, expressionDGEData, ncAnnotation, rawExpressionData, traitsData

# Alternatively, create a button to upload the demo data
annotationData <- data("annotation_data")
expressionDGEData <- data("expression_DGE")
ncAnnotation <- data("nc_annotation")
rawExpressionData <- data("raw_expression")
traitsData <- data("traits")

# When all the data are uploaded, enable a button to click to test data format, then run:
lacenObject <- initLacen(annotationData = annotationData,
                         datCounts = rawExpressionData,
                         datExpression = expressionDGEData,
                         datTraits = traitsData,
                         ncAnnotation = ncAnnotation)
checkData(lacenObject)

# if checkData is TRUE, proceed to the next screen, else, print what checkData(lacenObject) will print

# 3.0 Filter and transform
# Create two box to the user to set pThreshold and fcThreshold, then run the next function and proceed to the next screen
lacenObject <- filterTransform(lacenObject = lacenObject,
                               pThreshold = pThreshold,
                               fcThreshold = fcThreshold,
                               filterMethod = "DEG")

# 4.0 Clustering
# Run the next function
selectOutlierSample(lacenObject,
                    height = FALSE,
                    plot = TRUE,
                    filename = "clusterTree.png")
# The output will be saved in "clusterTree.png", exhibit it.

# Create a box to the user to set the height and run the next function. The user should be able to repeat this step.
selectOutlierSample(lacenObject,
                    height = FALSE,
                    plot = TRUE,
                    filename = "clusterTree.png")
# The output will be saved in "clusterTree.png", update the exhibition.

# Create a button to accept the height and run the next function, and then proceed to the next screen.
lacenObject <- cutOutlierSample(lacenObject,
                                height = height)

# 5.0 Soft threshold
# Run the next function
plotSoftThreshold(lacenObject,
                  filename = "indicePower.png",
                  maxBlockSize = 10000,
                  plot = FALSE)
# The output will be saved in "indicePower.png", exhibit it.


# Create a camp to the user to select the indice power, then run the next function and proceed to the next screen.
lacenObject <- selectSoftThreshold(lacenObject = lacenObject,
                                   indicePower = indicePower)


# 6.0 Summarize and enrich modules
# Run the following functions
lacenObject <- summarizeAndEnrichModules(lacenObject = lacenObject,
                                         maxBlockSize = 40000,
                                         filename = "enrichedgraph.png")

stackedBarplot(lacenObject, filename = "stackedplot.png", plot = FALSE)

# The output are 2 files: "enrichedgraph.png" and "stackedplot.png", exhibit then and allow to click it to open in a new tab with zoom


# 6.0 Heatmap
# Create a camp to the user select module and submodule (submodule may be FALSE, so start it with FALSE)

heatmapTopConnectivity(lacenObject = lacenObject,
                       module = 3,
                       submodule = 2,
                       filename = "mod.png")

# The output will be saved in "mod.png", exhibit it then and allow to click it to open in a new tab with zoom


# 7.0 lnc-centric analysis
# Run the command
lncList <- lacenObject$summdf$gene_name[lacenObject$summdf$is_nc]

# Create the following box to receive user input:
# a. lncSymbol: A string, it should be able to autocomplete from any string from lncList, and only accept them
# b. mGenesNet: A integer
# c. nTerm: A integer
# d. sources: A drop menu with the string options: "GO:All", "GO:BP", "GO:MF", "GO:CC", "KEGG", "REAC"

# After the user pick the values, run the function
lncRNAEnrich(lncName = "LINC01055",
             lacenObject = lacenObject,
             nGenesNet = 80,
             nTerm = 20,
             sources = "GO:BP",
             netPath = "./net.png",
             enrPath = "./enr.png")

# The output are 2 files: "net.png" and "enr.png", exhibit then and allow to click it to open in a new tab with zoom
