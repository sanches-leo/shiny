
# Add this block and enable a selection box in load data
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


user_organism_input <- "user input from scientific names"
user_organism_index <- which(user_organism_input == scientific_name)
organism <- gprofiler_code[user_organism_index]
orgdb <- orgdb_package[user_organism_index]

if (!require(orgdb, quietly = TRUE))
  BiocManager::install(orgdb)

# Export those values to access in the server side
values$organism <- organism
values$orgdb <- orgdb
# In the server side, in summarizeAndEnrichModules function, add those values as the following example
values$lacenObject <- summarizeAndEnrichModules(values$lacenObject,
                                                maxBlockSize = 20000,
                                                filename = enriched_path,
                                                modPath = mod_path,
                                                log = TRUE,
                                                log_path = log_path,
                                                organism = values$organism,
                                                orgdb = values$orgdb)