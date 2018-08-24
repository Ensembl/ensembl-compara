setwd("C:/Users/Guillaume/Desktop/Stats")
attach(mtcars)
par(mfrow=c(2,2))

species = "Zebrafish"
old = T

dataset = read.table(paste0(if(old) "OldRun/" else "" ,species, "/", species ,"_Data.txt"), header = TRUE, na.strings = c("NA", "NULL"), dec = ".")
ntrans = read.table("PseudogeneData/TranscriptCount.txt", header = TRUE, na.strings = c("NA", "NULL"), dec = ".")

taxa = levels(dataset$node_name)
pseudo <- merge(x = dataset, y = ntrans, by = "stable_id")

summary(dataset)

ortho_one_one = dataset[ which(dataset$node_name %in% taxa & dataset$description == "ortholog_one2one"), ]
ortho_one_many = dataset[ which(dataset$node_name %in% taxa & dataset$description == "ortholog_one2many"), ]
ortho_many_many = dataset[ which(dataset$node_name %in% taxa & dataset$description == "ortholog_many2many"), ]
pseudogene = pseudo[which(pseudo$node_name %in% taxa & pseudo$description == "pseudogene_ortholog"), ]

transcribed = c("transcribed_processed_pseudogene", "transcribed_unprocessed_pseudogene", "transcribed_unitary_pseudogene")
pseudogeneT <- pseudogene[which(pseudogene$biotype %in% transcribed), ]
pseudogeneT$biotype <- factor(pseudogeneT$biotype)
normal = c("processed_pseudogene", "unprocessed_pseudogene", "unitary_pseudogene")
pseudogeneN <- pseudogene[which(pseudogene$biotype %in% normal), ]
pseudogeneN$biotype  <- factor(pseudogeneN$biotype)

# boxplot(pseudogeneN$perc_id ~ pseudogeneN$biotype)
# boxplot(pseudogeneT$perc_id ~ pseudogeneT$biotype)
#
# boxplot(pseudogeneN$perc_id ~ pseudogeneN$nb_transcripts)
# boxplot(pseudogeneT$perc_id ~ pseudogeneT$nb_transcripts)
#
# boxplot(ortho_one_one$perc_id, ylim = c(85, 100), main = "Orthologues 1:1")
# boxplot(ortho_one_many$perc_id, ylim = c(85, 100), main = "Orthologues 1:many")
# boxplot(ortho_many_many$perc_id, ylim = c(40, 100), main = "Orthologues many:many")
# boxplot(pseudogene$perc_id,  ylim = c(40, 100), main = "Pseudogenes Orthologues")

par(mfrow=c(1,1))

png(filename=paste0("Boxplot_Number_", species, "_", if(old) "Canonical"  else "Pseudogene", ".png"))
boxplot(pseudogeneT$perc_id ~ pseudogeneT$nb_transcripts, xlabel = "Number of transcripts",
        main = paste0("Boxplots of Human identity against ", species, "\n using ", if(old) "canonical"  else "pseudogene", " transcript"))
dev.off()

# par(mfrow=c(1,1))
#
# png(filename=paste0("Boxplot_", species, "_", if(old) "Canonical"  else "Pseudogene", ".png"))
# boxplot(pseudogeneN$perc_id, pseudogeneT$perc_id, names = c("Non-Transcribed", "Transcribed"),
#         main = paste0("Boxplots of Human identity against ", species, "\n using ", if(old) "canonical"  else "pseudogene", " transcript"))
#
# dev.off()
