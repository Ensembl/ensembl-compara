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

#How to plot the Jaccard index:
#Rscript plotLorentzCurve.r <INPUT> <OUTPUT.pdf>

args = commandArgs(trailingOnly=TRUE)

if (length(args)==0) {
    stop("Missing arguments: Rscript plotLorentzCurve.r <INPUT> <OUTPUT.pdf>", call.=FALSE)
}

library(ineq)
library(scales)

pdf(args[2])

A <- read.table(args[1],header=FALSE, sep="\t")
current<-as.numeric(A$V2)
previous<-as.numeric(A$V1)

lorentz_curve_current<-Lc(current, n = rep(1,length(current)), plot =F)
clorentz_curve_previous<-Lc(previous, n = rep(1,length(previous)), plot =F)
plot(clorentz_curve_previous, col="red",lty=1,lwd=3,main="Lorenz Curve of cluster size distributions",xlab="percentage of clusters", ylab="percentage of cluster size " )
lines(lorentz_curve_current,lty=1, lwd=3,col="blue")
legend("topleft", c( "previous", "current" ), lty=c(1,1), lwd=3, col=c("red", "blue"))

dev.off()
