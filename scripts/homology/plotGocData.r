#!/usr/bin/env Rscript

# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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
#   Rscript plotGocData.r your_tree.newick /your/output_directory/

args = commandArgs(trailingOnly = TRUE)
if (length(args) != 2) {
  stop('Two arguments are required: tree_file out_dir')
}

tree_file               = args[1]
out_dir                 = args[2]

library(ape)
library(reshape2)
library(ggplot2)

heatmap.phylo = function(x_mat, tree_row, tree_col, filename, maintitle, legend_text, ...) {
  # x_mat:     numeric matrix, with rows and columns labelled with species names
  # tree_row:  phylogenetic tree (class phylo) to be used in rows
  # tree_col:  phylogenetic tree (class phylo) to be used in columns
  # filename:  path to SVG for saving plot
  # maintitle: title for plot
  # legend_text: legend for plot
  # ... additional arguments to be passed to image function
  
  pdf(filename, width=20, height=20, pointsize=0.03)
  
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
  plot(tree_col, direction='downwards', show.tip.label=FALSE, xaxs='i', x.lim=x_lim, main=maintitle, cex.main=3)
  
  # Add legend
  plot(NA, axes=FALSE, ylab='', xlab='', ylim=c(0,1), xlim=c(0,1))
  legend('center', legend_text, ncol=2, cex=4, ...)
  
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

# https://stackoverflow.com/questions/18509527/first-letter-to-upper-case
firstup <- function(x) {
  substr(x, 1, 1) <- toupper(substr(x, 1, 1))
  x
}

phylo_tree = read.tree(paste(out_dir, tree_file, sep='/'))
phylo_tree = ladderize(collapse.singles(phylo_tree), FALSE)
phylo_tree$tip.label <- firstup(phylo_tree$tip.label)

goc_summary_avg    = read.delim(paste(out_dir, "heatmap_avg.data", sep='/'), sep="\t", header=TRUE, na.strings=c('NULL'))
goc_avg_matrix   = as.matrix(acast(goc_summary_avg, name1~name2, value.var='goc_avg'))

goc_summary_median    = read.delim(paste(out_dir, "heatmap_median.data", sep='/'), sep="\t", header=TRUE, na.strings=c('NULL'))
goc_median_matrix   = as.matrix(acast(goc_summary_median, name1~name2, value.var='goc_median'))

species_names <- unique(goc_summary_avg$name1)
remove_tips <- setdiff(phylo_tree$tip.label, species_names)
phylo_tree <- drop.tip(phylo_tree, remove_tips, trim.internal = TRUE, subtree = FALSE,
         root.edge = 0, rooted = is.rooted(phylo_tree), collapse.singles = TRUE,
         interactive = FALSE)

heatmap_col_avg    = rev(heat.colors(10))
heatmap_legend_avg <- c('10%', '20%', '30%', '40%', '50%', '60%', '70%', '80%', '90%', '100%')
heatmap_col_median    = rev(heat.colors(5))
heatmap_legend_median <- c('0%', '25%', '50%', '75%', '100%')

#-------------------------------------------------------------------------
#                               Heatmaps
#-------------------------------------------------------------------------
heatmap.phylo(goc_avg_matrix, phylo_tree, phylo_tree, paste(out_dir, 'goc_avg.pdf', sep='/'), 'Average GOC score', heatmap_legend_avg, col=heatmap_col_avg, fill=heatmap_col_avg, border=heatmap_col_avg)
heatmap.phylo(goc_median_matrix, phylo_tree, phylo_tree, paste(out_dir, 'goc_median.pdf', sep='/'), 'Median GOC score', heatmap_legend_median, col=heatmap_col_median, fill=heatmap_col_median, border=heatmap_col_median)

#-------------------------------------------------------------------------
#                       Barplots sorted by GOC scores
#-------------------------------------------------------------------------

# Gene count
#---------------------------------------------------------------------------------------------------
pdf(paste(out_dir, 'gene_count.pdf', sep='/'),width=6,height=4,paper='special')
num_of_genes_dat = read.delim(paste(out_dir, 'gene_count.data', sep='/'), sep="\t", header=TRUE, na.strings=c('NULL'))
num_of_genes_plot <- melt(num_of_genes_dat, id.vars='species')
ggplot(num_of_genes_plot, aes(x=species, y=value)) + geom_bar(stat='identity') + facet_grid(.~variable) + coord_flip() + labs(x='',y='') + theme(text = element_text(size=5)) + theme(axis.text.x = element_text(size=rel(0.4)))
