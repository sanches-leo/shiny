# Load Data

The `lacen` package requires five input datasets to commence analysis:

1. **Expression Counts Dataframe** (`Upload Raw Expression Data`): A csv table composed of non-normalized RNA-seq counts, structured with genes as rows and samples as columns. Gene identifiers (gene symbols or IDs) should be used as row names, and sample identifiers should appear as column names.

2. **Differential Expression Results** (`Upload Expression DGE Data`): A csv table summarizing differential expression analysis results. By default, standard outputs from tools such as Limma can be directly used. Alternatively, the dataframe can include three required columns: `"ID"` (gene identifier), `"log2FC"` (log2 fold-change between conditions), and `"pvalue"` (statistical significance), arranged in this exact order.

3. **Experimental Conditions Dataframe (Traits)** (`Upload Traits Data`): A two-column dataframe specifying sample identifiers and their respective experimental condition labels. Columns must be explicitly named `"Sample"` (sample identifier) and `"Trait"` (numeric condition/group identifier), respectively. Experimental conditions must be numerically encoded (e.g., "0" and "1" for two different groups).

4. **Gene Annotation Data** (`Upload Annotation Data`): A two-column csv linking gene identifiers to gene names, with columns specifically labeled `"gene_id"` and `"gene_name"`. Annotation data can be directly loaded from a GTF file. 
   - **Note**: if analysis is based solely on gene symbols, both columns might replicate the same symbol.

5. **Non-coding RNA Annotation Dataframe** (`Upload ncAnnotation Data`): A specific subset of the annotation data (`annotationData`) containing only long non-coding RNA entries. Non-coding RNA annotation data can also be directly loaded from a GTF file. 

