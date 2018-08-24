library(stringr)

# Style Functions -------------------------------

plot_style <- function(biotype)
{
  # Unitary pseudogene [Symb : []]
  X = str_extract(biotype, "processed")
  Y = str_extract(biotype, "unproccessed")
  Z = str_extract(biotype, "unitary")
  if(!is.na(X))
  {
    return(0)
  }
  ## Unprocessed Pseudogene [Symb : X]
  else if(!is.na(Y))
  {
    return(2)
  }

  ## Unprocessed Pseudogene [Symb : O]
  else if(!is.na(Z))
  {
    return(4)
  }

  ## Other pseudogene Biotype
  return(1)
}

plot_color <- function(biotype)
{
  # Unitary pseudogene [Symb : []]
  X = str_extract(biotype, "transcribed")
  if(!is.na(X))
  {
    return("blue")
  }

  ## Other pseudogene Biotype
  return("red")
}

# Load Data --------------------------------

setwd("C:/Users/Guillaume/Desktop/Stats")
speciesList = c("Chimpanzee")
attach(mtcars)


for(species in speciesList)
{

dataset = read.table(paste0(species, "/", species ,"_Data.txt"), header = TRUE, na.strings = c("NA", "NULL"), dec = ".")
biotypes = read.table("PseudogeneData/Biotypes.txt", header = TRUE, na.strings = c("NA", "NULL"), dec = ".")
bplenght = read.table("PseudogeneData/TranscriptLenght.txt", header = TRUE, na.strings = c("NA", "NULL"), dec = ".")
repeats = read.table("PseudogeneData/Repeats.txt", header = FALSE, na.strings = c("NA", "NULL"), dec = ".")
colnames(repeats) <- c("stable_id", "count", "size")

taxa = levels(dataset$node_name)

pseudo <- merge(x = dataset, y = biotypes, by = "stable_id")
pseudo <- merge(x = pseudo, y = bplenght, by = "stable_id")
pseudo <- merge(x = pseudo, y = repeats, by = "stable_id")

summary(dataset)

ortho_one_one = dataset[ which(dataset$node_name %in% taxa & dataset$description == "ortholog_one2one"), ]
pseudogene = pseudo[which(pseudo$node_name %in% taxa & pseudo$description == "pseudogene_ortholog"), ]
pseudogene$lengthA = pseudogene$length - pseudogene$size

Colors = sapply(pseudogene$biotype, plot_color)
Style = sapply(pseudogene$biotype, plot_style)


# ScatterPlot -------------------------------------------------------------
## Plotting percentage of ID in Query/Target

par(mfrow=c(2,2))
threshold = 80


plot(x = ortho_one_one$perc_id, y = ortho_one_one$perc_id.1, col = "blue", pch = 20, cex = 0.5, type = 'p',
     xlab = "%id in Human", ylab = paste("% Identity in", species), xlim = c(0, 100), ylim = c(0, 100))
points(x = pseudogene$perc_id, y = pseudogene$perc_id.1, col = "red", pch = Style, cex = 0.5, type = 'p')
lines(x = c(0, 100), y = c(threshold, threshold), col = "black")
lines(x = c(threshold, threshold), y = c(0, 100), col = "black")
## Plotting percentage of coverage in Query/Target
plot(x = ortho_one_one$perc_cov, y = ortho_one_one$perc_cov.1, col = "blue", pch = 20, cex = 0.5, type = 'p',
     xlab = "%cov in Human", ylab = paste("% Coverage in", species))
points(x = pseudogene$perc_cov, y = pseudogene$perc_cov.1, col = "red", pch = Style, cex = 0.5)


## Plotting percentage Cov / Percentage Id on Query
plot(x = ortho_one_one$perc_cov, y = ortho_one_one$perc_id, col = "blue", pch = 20, cex = 0.5, type = 'p',
     xlab = paste("% Coverage in", species), ylab = paste("% Identity in", species))
points(x = pseudogene$perc_cov, y = pseudogene$perc_id, col = "red", pch = Style, cex = 0.5)

## Plotting percentage Cov / Percentage Id on Target
plot(x = ortho_one_one$perc_cov.1, y = ortho_one_one$perc_id.1, col = "blue", pch = 20, cex = 0.5, type = 'p',
     xlab = "%cov in Human", ylab = "%id in Human")
points(x = pseudogene$perc_cov.1, y = pseudogene$perc_id.1, col = "red", pch = Style, cex = 0.5)

dev.print(pdf, paste0(species, "/Scatterplot_", species, ".pdf"))


# Identity Density --------------------------------------------------------
plot(density(ortho_one_one$perc_id), xlab = "% of Identity", ylab = "Density", main = paste("Density of Human Identity with 1:1 Orthologue with", species))
plot(density(ortho_one_one$perc_id.1), xlab = "% of Identity", ylab = "Density", main = paste("Density of", species, "Identity with 1:1 Orthologue with Human"))
plot(density(pseudogene$perc_id), xlab = "% of Identity", ylab = "Density", main = paste("Density of Human Identity with Pseudogene Orthologue with", species))
plot(density(pseudogene$perc_id.1), xlab = "% of Identity", ylab = "Density", main = paste("Density of", species, "Identity with Pseudogene Orthologue with Human"))
dev.print(pdf, paste0(species, "/Identity_Density_", species, ".pdf"))

# Coverage Density --------------------------------------------------------
plot(density(ortho_one_one$perc_cov), xlab = "% of Coverage", ylab = "Density", main = paste("Density of Human Coverage with 1:1 Orthologue with", species))
plot(density(ortho_one_one$perc_cov.1), xlab = "% of Coverage", ylab = "Density", main = paste("Density of", species, "Coverage with 1:1 Orthologue with Human"))
plot(density(pseudogene$perc_cov), xlab = "% of Coverage", ylab = "Density", main = paste("Density of Human Coverage with 1:1 Orthologue with", species))
plot(density(pseudogene$perc_cov.1), xlab = "% of Coverage", ylab = "Density", main = paste("Density of", species, "Coverage with Pseudogene Orthologue with Human"))
dev.print(pdf, paste0(species, "/Coverage_Density_", species, ".pdf"))



# Descrimination between Transcribed Pseudogene And Not Transcribed Pseudogenes --------------------
transcribed = c("transcribed_processed_pseudogene", "transcribed_unprocessed_pseudogene", "transcribed_unitary_pseudogene")
pseudogeneT <- pseudogene[which(pseudogene$biotype %in% transcribed), ]
pseudogeneT$biotype <- factor(pseudogeneT$biotype)
normal = c("processed_pseudogene", "unprocessed_pseudogene", "unitary_pseudogene")
pseudogeneN <- pseudogene[which(pseudogene$biotype %in% normal), ]
pseudogeneN$biotype <- factor(pseudogeneN$biotype)

# Biotype Boxplots --------------------------------------------------------
boxplot(pseudogeneT$perc_id ~ pseudogeneT$biotype, main = "% of Identity in Human For Transcribed Pseudogene")
boxplot(pseudogeneN$perc_id ~ pseudogeneN$biotype, main = "% of Identity in Human For Non-Transcribed Pseudogene")

boxplot(pseudogeneT$perc_id.1 ~ pseudogeneT$biotype, main = paste("% of Identity in", species, " for Transcribed Pseudogene"))
boxplot(pseudogeneN$perc_id.1 ~ pseudogeneN$biotype, main = paste("% of Identity in", species, " for Non-Transcribed Pseudogene"))
dev.print(pdf, paste0(species, "/Biotypes_Identities_Boxplots", species, ".pdf"))

boxplot(pseudogeneT$perc_cov ~ pseudogeneT$biotype, main = "% of Coverage in Human For Transcribed Pseudogene")
boxplot(pseudogeneN$perc_cov ~ pseudogeneN$biotype, main = "% of Coverage in Human For Non-Transcribed Pseudogene")

boxplot(pseudogeneT$perc_cov.1 ~ pseudogeneT$biotype, main = paste("% of Coverage in", species, "for Transcribed Pseudogene"))
boxplot(pseudogeneN$perc_cov.1 ~ pseudogeneN$biotype, main = paste("% of Coverage in", species, "for Non-Transcribed Pseudogene"))
dev.print(pdf, paste0(species, "/Biotypes_Coverage_Boxplots", species, ".pdf"))

plot(x = pseudogene$length, y = pseudogene$perc_id, col = Colors, pch = Style, cex = 0.5,
     xlab = "Lenght of sequence in BP", ylab = "%id in Human", xlim = c(0, 12000), ylim = c(0, 100))

plot(density(pseudogeneT$length), main = "Lenght of sequence in transcribed Pseudogenes", col = "blue", ylim = c(0, 8.5e-4))
lines(density(pseudogeneN$length), col = "red")

plot(ecdf(pseudogeneT$length), main = "Lenght of sequence in transcribed Pseudogenes", col = "blue")
lines(ecdf(pseudogeneN$length), col = "red")


## Density for
m = quantile(pseudogeneT$length)[3]

par(mfrow=c(2,2))
plot(density(pseudogeneT$perc_id), xlab = "% of Identity in Human", ylab = "Density", main = "Density of Identity in Transcribed Pseudogene in Human", col = "red", ylim = c(0, 0.05))
lines(density(pseudogeneN$perc_id), col = "blue", ylim = c(0, 0.05))

plot(density(pseudogeneT$perc_id.1), xlab = paste("% of Identity in", species), ylab = "Density", main = paste("Density of Identity in Transcribed Pseudogene in", species), col = "red", ylim = c(0, 0.05))
lines(density(pseudogeneN$perc_id.1), main = paste("Density of Identity in Non-Transcribed Pseudogene in", species), col = "blue", ylim = c(0, 0.05))

plot(density(pseudogeneT$perc_cov), xlab = "% of Coverage in Human", ylab = "Density", main = "Density of Coverage in Transcribed Pseudogene in Human", col = "red", ylim = c(0, 0.05))
lines(density(pseudogeneN$perc_cov), col = "blue", ylim = c(0, 0.05))

plot(density(pseudogeneT$perc_cov.1), xlab = paste("% of Coverage in", species), ylab = "Density", main = "Density of Idenity in Pseudogene", col = "red", ylim = c(0, 0.05))
lines(density(pseudogeneN$perc_cov.1), col = "blue", ylim = c(0, 0.05))

dev.print(pdf, paste0(species, "/Transcribed_Untranscribed_", species, ".pdf"))

## lines(density(pseudogeneT[which(pseudogeneT$length >= m & pseudogeneT$length < M), ]$perc_id), col = "green")
par(mfrow=c(2,2))

hist(pseudogeneT$size)
hist(pseudogeneN$size)

plot(pseudogeneT$size, pseudogeneT$length, col = "blue")
points(pseudogeneN$size, pseudogeneN$length, col = "red")


pseudogeneT$lengthA = pseudogeneT$length - pseudogeneT$size
pseudogeneN$lengthA = pseudogeneN$length - pseudogeneN$size

plot(x = pseudogene$length, y = pseudogene$perc_id, col = Colors, pch = Style, cex = 0.5,
     xlab = "Lenght of sequence in BP", ylab = "%id in Human", xlim = c(0, 12000), ylim = c(0, 100))

plot(x = pseudogene$lengthA, y = pseudogene$perc_id, col = Colors, pch = Style, cex = 0.5,
     xlab = "Lenght of sequence in BP", ylab = "%id in Human", xlim = c(0, 12000), ylim = c(0, 100))

# Identity Density --------------------------------------------------------
par(mfrow=c(2,2))
plot(x = pseudogene$perc_id, y = pseudogene$perc_id.1, col = Colors, pch = Style, cex = 0.5,
     xlab = "%id in Human", ylab = paste("%id in", species), xlim = c(0, 100), ylim = c(0, 100))
lines(x = c(0, 100), y=c(80, 80), col = "black")
lines(x = c(80, 80), y=c(0, 100), col = "black")
plot(x = pseudogene$perc_cov, y = pseudogene$perc_cov.1, col = Colors, pch = Style, cex = 0.5,
     xlab = "%id in Human", ylab = paste("%id in", species), xlim = c(0, 100), ylim = c(0, 100))
plot(x = pseudogene$perc_cov, y = pseudogene$perc_id, col = Colors, pch = Style, cex = 0.5,
     xlab = "%id in Human", ylab = paste("%id in", species), xlim = c(0, 100), ylim = c(0, 100))
plot(x = pseudogene$perc_cov.1, y = pseudogene$perc_id.1, col = Colors, pch = Style, cex = 0.5,
     xlab = "%id in Human", ylab = paste("%id in", species), xlim = c(0, 100), ylim = c(0, 100))

}
