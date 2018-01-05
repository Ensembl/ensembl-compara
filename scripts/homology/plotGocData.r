# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


#Data can be exctracted from the database by running the generateGocBreakout.pl script:
#   perl generateGocBreakout.pl -outdir /homes/mateus/goc -user ensro -database mateus_tuatara_86 -hostname mysql-treefam-prod:4401

#How to plot the data:
#   Rscript plotGocData.r your_tree.newick /your/output_directory/ your_reference_species_file

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop('Four arguments are required: tree_file out_dir reference_species_file')
}

tree_file               = args[1]
out_dir                 = args[2]
reference_species_file  = args[3] #File with one reference species per line

library(ape)
library(reshape2)
library(ggplot2)

heatmap.phylo = function(x_mat, tree_row, tree_col, filename, maintitle, ...) {
  # x_mat:     numeric matrix, with rows and columns labelled with species names
  # tree_row:  phylogenetic tree (class phylo) to be used in rows
  # tree_col:  phylogenetic tree (class phylo) to be used in columns
  # filename:  path to SVG for saving plot
  # maintitle: title for plot
  # ... additional arguments to be passed to image function
  
  pdf(filename, width=10, height=10)
  
  # The matrix needs to be re-ordered, to match the order of the tree tips.
  tree_row_is_tip    = tree_row$edge[,2] <= length(tree_row$tip)
  tree_row_tip_index = tree_row$edge[tree_row_is_tip, 2]
  tree_row_tip_names = tree_row$tip[tree_row_tip_index]
  
  tree_col_is_tip    = tree_col$edge[,2] <= length(tree_col$tip)
  tree_col_tip_index = tree_col$edge[tree_col_is_tip, 2]
  tree_col_tip_names = tree_col$tip[tree_col_tip_index]
  
  x_mat = x_mat[tree_row_tip_names, tree_col_tip_names]
  
  # Work out the axes limits, then set up a 3x3 grid for plotting
  x_lim = c(0.5, ncol(x_mat)+0.5)
  y_lim = c(0.5, nrow(x_mat)+0.5)
  layout(matrix(c(0,1,2,3,4,5,0,6,0), nrow=3, byrow=TRUE), width=c(1,3,1.5), height=c(1,3,1.5))
  
  # Plot tree downwards, at top of plot
  par(mar=c(0,0,2,0))
  plot(tree_col, direction='downwards', show.tip.label=FALSE, xaxs='i', x.lim=x_lim, main=maintitle)
  
  # Add legend
  plot(NA, axes=FALSE, ylab='', xlab='', ylim=c(0,1), xlim=c(0,1))
  legend('center', c('10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%', '100%'), ncol=2, ...)
  
  # Plot tree on left side of plot
  par(mar=rep(0,4))
  plot(tree_row, direction='rightwards', show.tip.label=FALSE, yaxs='i', y.lim=y_lim)
  
  # Plot heatmap
  par(mar=rep(0,4), xpd=TRUE)
  image((1:nrow(x_mat))-0.5, (1:ncol(x_mat))-0.5, x_mat, xaxs='i', yaxs='i', axes=FALSE, xlab='',ylab='', ...)
  
  # Plot names on right side of plot
  par(mar=rep(0,4))
  plot(NA, axes=FALSE, ylab='', xlab='', yaxs='i', xlim=c(0,2), ylim=y_lim)
  text(rep(0, nrow(x_mat)), 1:nrow(x_mat), gsub('_', ' ', tree_row_tip_names), pos=4)
  
  # Plot names on bottom of plot
  par(mar=rep(0,4))
  plot(NA, axes=FALSE, ylab='', xlab='', xaxs='i', ylim=c(0,2), xlim=x_lim)
  text(1:ncol(x_mat), rep(2,ncol(x_mat)), gsub('_', ' ', tree_col_tip_names), srt=90, pos=2, offset=0)
  
  dev.off()
}

#-------------------------------------------------------------------------
#                        Barplots with topology
#-------------------------------------------------------------------------
barplot.phylo <- function(x_df, x_df_cols, x_df_labels, species, tree_row, filename, ...) {
  # x_df:        dataframe with columns name1 and name2 with species names
  # x_df_cols:   list of column names from the data frame to plot
  # x_df_labels: list of labels to use in legend
  # species:     species name
  # tree_row:    phylogenetic tree (class phylo) to be used in rows
  # filename:    path to SVG for saving plot
  # ... additional arguments to be passed to image function
  
  pdf(filename, width=10, height=6)
  
  # The dataframe needs to be re-ordered, to match the order of the tree tips.
  tree_row_is_tip    = tree_row$edge[,2] <= length(tree_row$tip)
  tree_row_tip_index = tree_row$edge[tree_row_is_tip, 2]
  tree_row_tip_names = tree_row$tip[tree_row_tip_index]
  
  x_df  = subset(x_df, name2 == species, select=c('name1', x_df_cols))
  x_df  = x_df[match(tree_row_tip_names, x_df$name1),]
  x_df  = subset(x_df, select=x_df_cols)
  x_mat = data.matrix(x_df)
  
  # Work out the axis limits, then set up a 2x3 grid for plotting
  maintitle = paste('GOC score distribution for', gsub('_', ' ', species))
  y_lim = c(0.5, nrow(x_df)+0.5)
  layout(matrix(c(0,1,0,2,3,4),nrow=2, byrow=TRUE), width=c(1,3,1), height=c(0.2,3))
  
  # Add title
  par(mar=c(0,0,2,0))
  plot(NA, axes=FALSE, main=maintitle, xlim=c(0,1), ylim=c(0,1))
  
  # Plot tree on left side of plot
  par(mar=c(2,0,0,0))
  plot(tree_row, direction='rightwards', show.tip.label=FALSE, yaxs='i', y.lim=y_lim)
  
  # Add legend
  legend('topleft', x_df_labels, ...)
  
  # Plot bar chart
  par(mar=c(2,0,0,0))
  barplot(t(x_mat/rowSums(x_mat)), horiz=TRUE, xaxs='i', yaxs='i', axisnames=FALSE, xlab='',ylab='', ...)
  
  # Plot names on right side of plot
  par(mar=c(2,0,0,0))
  plot(NA, axes=FALSE, ylab='', xlab='', yaxs='i', xlim=c(0,2), ylim=y_lim)
  text(rep(0, nrow(x_mat)), 1:nrow(x_mat), gsub('_', ' ', tree_row_tip_names), pos=4)
  
  dev.off()
}

phylo_tree = read.tree(paste(out_dir, tree_file, sep='/'))
phylo_tree = ladderize(collapse.singles(phylo_tree), FALSE)

goc_summary    = read.delim(paste(out_dir, "heatmap.data", sep='/'), sep="\t", header=TRUE, na.strings=c('NULL'))
goc_0_matrix   = as.matrix(acast(goc_summary, name1~name2, value.var='goc_eq_0'))
goc_25_matrix  = as.matrix(acast(goc_summary, name1~name2, value.var='goc_gte_25'))
goc_50_matrix  = as.matrix(acast(goc_summary, name1~name2, value.var='goc_gte_50'))
goc_75_matrix  = as.matrix(acast(goc_summary, name1~name2, value.var='goc_gte_75'))
goc_100_matrix = as.matrix(acast(goc_summary, name1~name2, value.var='goc_eq_100'))
n_goc_cols     = c('n_goc_0', 'n_goc_25', 'n_goc_50', 'n_goc_75', 'n_goc_100')
n_goc_labels   = c('GOC score = 0', 'GOC score = 25', 'GOC score = 50', 'GOC score = 75', 'GOC score = 100')


heatmap_col    = rev(heat.colors(10))
barplot_col    = rainbow(length(n_goc_cols))

goc_100_matrix

#-------------------------------------------------------------------------
#                               Heatmaps
#-------------------------------------------------------------------------
heatmap.phylo(goc_0_matrix,   phylo_tree, phylo_tree, paste(out_dir, 'goc_0.pdf', sep='/'),   'Percentage of orthologs with GOC score = 0',   col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_25_matrix,  phylo_tree, phylo_tree, paste(out_dir, 'goc_25.pdf', sep='/'),  'Percentage of orthologs with GOC score >= 25', col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_50_matrix,  phylo_tree, phylo_tree, paste(out_dir, 'goc_50.pdf', sep='/'),  'Percentage of orthologs with GOC score >= 50', col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_75_matrix,  phylo_tree, phylo_tree, paste(out_dir, 'goc_75.pdf', sep='/'),  'Percentage of orthologs with GOC score >= 75', col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_100_matrix, phylo_tree, phylo_tree, paste(out_dir, 'goc_100.pdf', sep='/'), 'Percentage of orthologs with GOC score = 100', col=heatmap_col, fill=heatmap_col, border=heatmap_col)


for (species in levels(goc_summary$name1)) {
  filename = paste(out_dir, paste('goc_', species, '.pdf', sep=''), sep='/')
  barplot.phylo(goc_summary, n_goc_cols, n_goc_labels, species, phylo_tree, filename, fill=barplot_col, col=barplot_col)
}


#-------------------------------------------------------------------------
#                       Barplots sorted by GOC scores
#-------------------------------------------------------------------------


# Gene count
#---------------------------------------------------------------------------------------------------
pdf(paste(out_dir, 'gene_count.pdf', sep='/'),width=6,height=4,paper='special')
num_of_genes_dat = read.delim(paste(out_dir, 'gene_count.data', sep='/'), sep="\t", header=TRUE, na.strings=c('NULL'))
num_of_genes_plot <- melt(num_of_genes_dat, id.vars='species')
ggplot(num_of_genes_plot, aes(x=species, y=value)) + geom_bar(stat='identity') + facet_grid(.~variable) + coord_flip() + labs(x='',y='') + theme(text = element_text(size=5)) + theme(axis.text.x = element_text(size=rel(0.4)))


# Orthologues count
#---------------------------------------------------------------------------------------------------
pdf(paste(out_dir, 'number_of_orthologues.pdf', sep='/'),width=6,height=4,paper='special')
num_of_orthologues_dat  = read.delim(paste(out_dir, 'homology.data', sep='/'), sep="\t", header=TRUE, na.strings=c('NULL'))
num_of_orthologues_plot <- melt(num_of_orthologues_dat, id.vars='species')
options(scipen=10000)
ggplot(num_of_orthologues_plot, aes(x=species, y=value)) + geom_bar(stat='identity') + facet_grid(.~variable) + coord_flip() + labs(x='',y='') + theme(text = element_text(size=5)) + theme(axis.text.x = element_text(size=rel(0.8)))

# References above 100
#---------------------------------------------------------------------------------------------------
reference_species = read.delim(reference_species_file, sep="\n", header=FALSE, na.strings=c('NULL'))

file_name = paste(out_dir, 'ordered_goc_100_refernces.pdf', sep='/')
pdf(file_name,width=6,height=4,paper='special')
for (ref_species in levels(reference_species$V1)) {
    raw_data = read.delim( paste(paste(out_dir,ref_species,sep='/'), "_ref.dat", sep=''), header = TRUE, sep = ";")
    raw_data$threshold = as.factor(sapply(raw_data$threshold , function(x){strsplit(as.character(x), split = "X_")[[1]][2]}))

    x = raw_data[raw_data$threshold == "100",]

    species_list = x[rev(order(x$goc)),]$species
    taxon_list = x[rev(order(x$goc)),]$taxon
    sorted_species_list = rev(species_list)
    sorted_taxon_list = rev(taxon_list)

    list = c("Crocodylia" = "chartreuse4"
              , "Birds" = "blue"
              , "Squamata" = "darkorange2"
              , "Mammals" = "red"
              , "Fish" = "darkcyan"
              , "Testudines" = "black"
              , "Amphibia" = "deeppink")

    raw_data$species = factor(raw_data$species, levels = sorted_species_list)
    raw_data$taxonomy = sapply(raw_data$taxon, function(x){attributes(list[list == x])[[1]]})

    graph_title = paste("GOC scores, ordered by GOC=100, reference: ",ref_species,sep='')

    print (ggplot(data = raw_data, aes(x = species, y = goc, fill = threshold, colour = taxonomy))
                + geom_bar(stat="identity", size = 0)
                + coord_flip()
                + theme(axis.text.y = element_text(colour = as.character(sorted_taxon_list)) , axis.text=element_text(size=7))
                + ggtitle(graph_title) + theme(plot.title = element_text(size = 7, face = "bold"))
                + guides(colour = guide_legend(override.aes = list(size=1)))
                + scale_colour_manual(values = list)
        )
}

# References above threshold with splits
#---------------------------------------------------------------------------------------------------
file_name = paste(out_dir, 'above_with_splits_references.pdf', sep='/')
pdf(file_name,width=6,height=4,paper='special')
for (ref_species in levels(reference_species$V1)) {

    raw_data = read.delim( paste(paste(out_dir,ref_species,sep='/'), "_above_with_splits.dat", sep=''), header = TRUE, sep = ";")

    x <- raw_data[raw_data$threshold == "above",]
    species_list <- x[rev(order(x$goc)),]$species
    taxon_list <- x[rev(order(x$goc)),]$taxon
    sorted_species_list <- rev(species_list)
    sorted_taxon_list <- rev(taxon_list)

    list <- c("Crocodylia" = "chartreuse4"
              , "Birds" = "blue"
              , "Squamata" = "darkorange2"
              , "Mammals" = "red"
              , "Fish" = "darkcyan"
              , "Testudines" = "black"
              , "Amphibia" = "deeppink")

    raw_data$species <- factor(raw_data$species, levels = sorted_species_list)
    raw_data$taxonomy <- sapply(raw_data$taxon, function(x){attributes(list[list == x])[[1]]})

    graph_title = paste("GOC scores above and under 50, reference: ",ref_species,sep='')

    print (ggplot(data = raw_data, aes(x = species, y = goc, fill = threshold, colour = taxonomy))
                + geom_bar(stat="identity", size = 0) + coord_flip()
                + theme(axis.text.y = element_text(colour = as.character(sorted_taxon_list)) , axis.text=element_text(size=7))
                + ggtitle(graph_title) + theme(plot.title = element_text(size = 7, face = "bold"))
                + guides(colour = guide_legend(override.aes = list(size=1)))
                + scale_colour_manual(values = list)
    )
}

# References above threshold without splits
#---------------------------------------------------------------------------------------------------
file_name = paste(out_dir, 'above_threshold_references.pdf', sep='/')
pdf(file_name,width=6,height=4,paper='special')
for (ref_species in levels(reference_species$V1)) {

    raw_data = read.delim( paste(paste(out_dir,ref_species,sep='/'), "_ref_above_threshold.dat", sep=''), header = TRUE, sep = ";")

    species_list <- raw_data[rev(order(raw_data$perc_orth_above_goc_thresh)),]$species
    taxon_list <- raw_data[rev(order(raw_data$perc_orth_above_goc_thresh)),]$taxon
    sorted_species_list <- rev(species_list)
    sorted_taxon_list <- rev(taxon_list)
    raw_data$species                     <- factor(raw_data$species, levels = sorted_species_list)

    graph_title = paste("Number of GOC>=50, reference: ",ref_species,sep='')

    print(ggplot(data = raw_data[,c(1:2)], aes(x = species, y = perc_orth_above_goc_thresh, fill = perc_orth_above_goc_thresh))
                + geom_bar(stat="identity") + coord_flip()
                + theme(axis.text.y = element_text(colour = c(sorted_taxon_list)), axis.text=element_text(size=7))
                + ggtitle("Number of GOC>=50: Tuatara as reference") + theme(plot.title = element_text(size = 7, face = "bold"))

    )
}

