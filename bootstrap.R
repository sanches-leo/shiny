# Lacen bootstrap is a optional step that remakes the network 100 times, removing a fraction of genes each time to find the most robust modules and to remove genes that are not stable in its modules. 

# It comes after the Soft Threshold step, and it is OPTIONAL, so it shouldnt run automatically when soft threshold is picked. It should just go to bootstrap tab, giving the user the option to run or skip. Choosing to run the bootstrap, it will span a warning, telling the user that it could take a long time, from a couple hours to a couple days, depending on the dataset size. It should be wrapped in a trycatch as well to return an error if it couldnt run.


lacenObject <- lacenBootstrap(
  lacenObject = lacenObject,
  numberOfIterations = 100,
  maxBlockSize = 50000,
  csvPath = "bootstrap.csv",
  pathModGroupsPlot = "moduleGroups.png",
  pathStabilityPlot = "moduleStability.png",
)

# After fininshing running, both plots should be exhibited and the user could fill a second camp called bootstrap threshold based on those couple plots. Then the following function will run and the next step will be Summarize And Enrich as the usual.

lacenObject <- setBootstrap(lacenObject = lacenObject,
                            cutBootstrap = bootstrap_threshold)

