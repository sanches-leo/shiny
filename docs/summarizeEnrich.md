The core function of LACEN automatically constructs the final network, performs functional enrichment of the identified modules using the specified database, and generates a visual representation of the reduced enrichment results as a PNG file. Also, a module composition barplot is also generated, allowing the module composition visualization by protein-coding and lncRNA content alongside trait-module relationships.

The generated tree plot provides a structured summary of the functional enrichment of the network modules, containing the following key information:

Module Number – The identifier for the coexpression module.
Module-Trait Association – The correlation value between the module and the phenotype/trait of interest, along with its associated p-value.
Submodule Number – Identifies distinct submodules within a module.
Reduced Enrichment Description – The summarized functional categories significantly enriched in each submodule after redundancy reduction.
lncRNA Composition – The number of differentially expressed lncRNAs (DEGs) among the highly connected lncRNAs within the submodule.

> **Note:** Since lncRNAs often lack functional annotations in standard enrichment databases, LACEN applies a guilt-by-association approach. This assumes that an lncRNA may share similar biological roles with its coexpressed protein-coding genes within the same module or submodule. Given that highly connected lncRNAs can be associated with multiple submodules, there may be overlaps between lncRNAs across different submodules. This reflects the complexity of lncRNA functional associations and provides additional insights into their potential biological roles.

