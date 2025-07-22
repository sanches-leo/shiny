# Greetings

`lacen` is a dedicated R software package developed to facilitate integrative analysis of gene expression data, focusing specifically on the elucidation of functional roles for long non-coding RNAs (lncRNAs) through weighted gene co-expression network analysis (WGCNA). 

The package offers an intuitive, structured, and robust workflow that seamlessly integrates data handling, transformation, and network construction steps and includes advanced stability checks via bootstrap analyses. `lacen` is designed to be user-friendly and accessible, even for researchers without extensive computational or programming experience, guiding users through a clear and consistent analysis pathway.

Although initially optimized using human cancer RNA-seq datasets, the package is not limited to oncological studies and can handle data from numerous experimental contexts and organisms. The only strict requirements are that the input RNA-seq expression profiles must represent at least two sample conditions (for instance, two different biological or clinical groups), and input files must conform to the required format. Beyond human datasets, `lacen` supports most widely-researched organisms included in [Bioconductor's OrgDb annotation packages](https://www.bioconductor.org/packages/release/BiocViews.html#___OrgDb).

