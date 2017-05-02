# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2017] EMBL-European Bioinformatics Institute
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
#   Rscript plotGocData.r your_tree.newick heatmap.data /your/output_directory/

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 3) {
  stop('Three arguments are required: tree_file data_file out_dir')
}

tree_file = args[1]
data_file = args[2]
out_dir   = args[3]

library(ape)
library(reshape2)

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

phylo_tree = read.tree(tree_file)
phylo_tree = ladderize(collapse.singles(phylo_tree), FALSE)

goc_summary

goc_summary    = read.delim(data_file, sep="\t", header=TRUE, na.strings=c('NULL'))
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

heatmap.phylo(goc_0_matrix,   phylo_tree, phylo_tree, paste(out_dir, 'goc_0.pdf', sep='/'),   'Percentage of orthologs with GOC score = 0',   col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_25_matrix,  phylo_tree, phylo_tree, paste(out_dir, 'goc_25.pdf', sep='/'),  'Percentage of orthologs with GOC score >= 25', col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_50_matrix,  phylo_tree, phylo_tree, paste(out_dir, 'goc_50.pdf', sep='/'),  'Percentage of orthologs with GOC score >= 50', col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_75_matrix,  phylo_tree, phylo_tree, paste(out_dir, 'goc_75.pdf', sep='/'),  'Percentage of orthologs with GOC score >= 75', col=heatmap_col, fill=heatmap_col, border=heatmap_col)
heatmap.phylo(goc_100_matrix, phylo_tree, phylo_tree, paste(out_dir, 'goc_100.pdf', sep='/'), 'Percentage of orthologs with GOC score = 100', col=heatmap_col, fill=heatmap_col, border=heatmap_col)


for (species in levels(goc_summary$name1)) {
  filename = paste(out_dir, paste('goc_', species, '.pdf', sep=''), sep='/')
  barplot.phylo(goc_summary, n_goc_cols, n_goc_labels, species, phylo_tree, filename, fill=barplot_col, col=barplot_col)
}


