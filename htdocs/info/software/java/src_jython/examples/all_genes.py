import ensembl

for gene in ensembl.human.all_genes():
	print gene.accessionID, gene.description
