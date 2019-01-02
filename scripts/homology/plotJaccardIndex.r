# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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

#How to plot the Jaccard index:
#Rscript plotJaccardIndex.r <INPUT> <OUTPUT.pdf>

args = commandArgs(trailingOnly=TRUE)

if (length(args)==0) {
    stop("Missing arguments: Rscript plotJaccardIndex.r <INPUT> <OUTPUT.pdf>", call.=FALSE)
}

library(ggplot2)

pdf(args[2])
ji_vertebrate = read.delim(args[1], sep="\t", header=FALSE)
ggplot(ji_vertebrate, aes(ji_vertebrate$V2)) + geom_density() + geom_vline(aes(xintercept=0)) + xlim(0, 1.25) + theme(legend.text=element_text(size=10)) + theme(axis.text.x=element_text(size=10),axis.text.y=element_text(size=10),axis.title.x=element_text(size=10),axis.title.y=element_text(size=10))
dev.off()
