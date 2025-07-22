# Filter And Transform

This step prepares the data for network construction by filtering low-variation genes. Users can select filtering criteria based on either `differentially expressed genes (DEGs)` or the `median absolute deviation (MAD)`. Both methods will remove low count-genes. `DEG`-based filtering will use a variance threshold based on the variance of what the user consider differentially expressed. Otherwise, `MAD`-based filtering will select the n most variable genes. `MAD` filtering is advised when delaing with memmory limitation to reduce the dataset size.

