# Greetings

`lacen` is a dedicated R software package developed to facilitate integrative analysis of gene expression data, focusing specifically on the elucidation of functional roles for long non-coding RNAs (lncRNAs) through weighted gene co-expression network analysis (WGCNA). 

The package offers an intuitive, structured, and robust workflow that seamlessly integrates data handling, transformation, and network construction steps and includes advanced stability checks via bootstrap analyses. `lacen` is designed to be user-friendly and accessible, even for researchers without extensive computational or programming experience, guiding users through a clear and consistent analysis pathway.

Although initially optimized using human cancer RNA-seq datasets, the package is not limited to oncological studies and can handle data from numerous experimental contexts and organisms. The only strict requirements are that the input RNA-seq expression profiles must represent at least two sample conditions (for instance, two different biological or clinical groups), and input files must conform to the required format. Beyond human datasets, `lacen` supports most widely-researched organisms included in [Bioconductor's OrgDb annotation packages](https://www.bioconductor.org/packages/release/BiocViews.html#___OrgDb).

---

# Load Data

The `lacen` package requires five input datasets to commence analysis:

1. **Expression Counts Dataframe** (`Upload Raw Expression Data`): A csv table composed of non-normalized RNA-seq counts, structured with genes as rows and samples as columns. Gene identifiers (gene symbols or IDs) should be used as row names, and sample identifiers should appear as column names.

2. **Differential Expression Results** (`Upload Expression DGE Data`): A csv table summarizing differential expression analysis results. By default, standard outputs from tools such as Limma can be directly used. Alternatively, the dataframe can include three required columns: `"ID"` (gene identifier), `"log2FC"` (log2 fold-change between conditions), and `"pvalue"` (statistical significance), arranged in this exact order.

3. **Experimental Conditions Dataframe (Traits)** (`Upload Traits Data`): A two-column dataframe specifying sample identifiers and their respective experimental condition labels. Columns must be explicitly named `"Sample"` (sample identifier) and `"Trait"` (numeric condition/group identifier), respectively. Experimental conditions must be numerically encoded (e.g., "0" and "1" for two different groups).

4. **Gene Annotation Data** (`Upload Annotation Data`): A two-column csv linking gene identifiers to gene names, with columns specifically labeled `"gene_id"` and `"gene_name"`. Annotation data can be directly loaded from a GTF file. 
   - **Note**: if analysis is based solely on gene symbols, both columns might replicate the same symbol.

5. **Non-coding RNA Annotation Dataframe** (`Upload ncAnnotation Data`): A specific subset of the annotation data (`annotationData`) containing only long non-coding RNA entries. Non-coding RNA annotation data can also be directly loaded from a GTF file. 

---

# Filter And Transform

This step prepares the data for network construction by filtering low-variation genes. Users can select filtering criteria based on either `differentially expressed genes (DEGs)` or the `median absolute deviation (MAD)`. Both methods will remove low count-genes. `DEG`-based filtering will use a variance threshold based on the variance of what the user consider differentially expressed. Otherwise, `MAD`-based filtering will select the n most variable genes. `MAD` filtering is advised when delaing with memmory limitation to reduce the dataset size.

---

# Clustering

This step will allow the user to indentify if there is outliers in the samples and select a threshold to remove them. It's possible to Te-run the Clustering and visualize if the height is adequate. Samples selected under the height (red bar) will be kept.

---

# Soft Threshold

Selecting an appropriate soft-threshold power ensures a scale-free topology for your network. Inspect the resulting plot and choose the power value maximizing the model fit. It's advised to select the minimum threshold where the curve stabilize close to 0.9 and still has a connectivity > 50.

---

# Bootstrap

The bootstrap stability analysis assess the robustness of the gene network using the bootstrap method. This approach repeatedly builds networks 100 times, omitting subsets of genes to identify consistently stable modules. Reviewing the provided stability plots, a specify a stability cutoff to retain robust genes

---

# Summarize And Enrich

The core function of LACEN automatically constructs the final network, performs functional enrichment of the identified modules using the specified database, and generates a visual representation of the reduced enrichment results as a PNG file. Also, a module composition barplot is also generated, allowing the module composition visualization by protein-coding and lncRNA content alongside trait-module relationships.

The generated tree plot provides a structured summary of the functional enrichment of the network modules, containing the following key information:

Module Number – The identifier for the coexpression module.
Module-Trait Association – The correlation value between the module and the phenotype/trait of interest, along with its associated p-value.
Submodule Number – Identifies distinct submodules within a module.
Reduced Enrichment Description – The summarized functional categories significantly enriched in each submodule after redundancy reduction.
lncRNA Composition – The number of differentially expressed lncRNAs (DEGs) among the highly connected lncRNAs within the submodule.

> **Note:** Since lncRNAs often lack functional annotations in standard enrichment databases, LACEN applies a guilt-by-association approach. This assumes that an lncRNA may share similar biological roles with its coexpressed protein-coding genes within the same module or submodule. Given that highly connected lncRNAs can be associated with multiple submodules, there may be overlaps between lncRNAs across different submodules. This reflects the complexity of lncRNA functional associations and provides additional insights into their potential biological roles.

---

# Heatmap 

This step generates a heatmap for a selected module or module/submodule, visualizing the interconnectedness of genes based on the topological overlap matrix (TOM). The heatmap highlights the coexpression relationships between lncRNAs and protein-coding genes, helping to identify highly connected lncRNAs within the network.

By analyzing these highly connected lncRNAs, users can investigate their co-expressed protein-coding genes and infer potential functional roles using a guilt-by-association approach. Just input one module and submodule (optional) to analyze.

---

# lncRNA-Centric Analysis

For cases where an lncRNA does not cluster into any module or is filtered out by the standard module selection criteria, LACEN provides an alternative approach to analyze its connectivity. This function identifies the most connected genes associated with a specific lncRNA, generates a subnetwork visualization, and performs functional enrichment analysis.

Using a given lncRNA identifier and a LACEN object containing the coexpression network data, this analysis:

- Identifies the most highly correlated genes with the selected lncRNA using the topological overlap matrix (TOM).
- Performs functional enrichment analysis of this gene set, identifying enriched terms from:
    - Gene Ontology (GO): Biological Processes, Molecular Functions, Cellular Components.
    - Pathways: KEGG and Reactome.
- Generates a network plot showing the strongest coexpression relationships.
- Visualizes the enrichment results, helping to infer potential functions of the lncRNA.
