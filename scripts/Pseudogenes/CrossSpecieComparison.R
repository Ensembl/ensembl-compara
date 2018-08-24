setwd("C:/Users/Guillaume/Desktop/Stats")

  species1 = "Chimpanzee"
  species2 = "Mouse"

  dataset1= read.table(paste0(species1, "/", species1 ,"_Data.txt"), header = TRUE, na.strings = c("NA", "NULL"), dec = ".")
  dataset2= read.table(paste0(species2, "/", species2 ,"_Data.txt"), header = TRUE, na.strings = c("NA", "NULL"), dec = ".")

  biotypes = read.table("PseudogeneData/Biotypes.txt", header = TRUE, na.strings = c("NA", "NULL"), dec = ".")
  bplenght = read.table("PseudogeneData/TranscriptLenght.txt", header = TRUE, na.strings = c("NA", "NULL"), dec = ".")

  dataset = merge(dataset1, dataset2, by = "stable_id", na.rm = TRUE)
  dataset = na.omit(dataset)

  par(mfrow=c(2, 2))
  plot(dataset$perc_id.x, dataset$perc_id.y, )
  plot(dataset$cov.x, dataset$cov.y)
  plot(dataset$perc_id.1.x, dataset$perc_id.1.y)
  plot(dataset$cov.1.x, dataset$cov.1.y)
