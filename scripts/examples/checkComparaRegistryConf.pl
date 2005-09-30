#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::SimpleAlign;

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);

Bio::EnsEMBL::Registry->load_all($reg_conf);

my $comparaDBA  = Bio::EnsEMBL::Registry->get_DBAdaptor('compara', 'compara');

print($comparaDBA, "\n");

my $genomes = $comparaDBA->get_GenomeDBAdaptor->fetch_all;
foreach my $genomeDB (@{$genomes}) {
  my $compara_class = join(" ", $genomeDB->taxon->classification);
  printf("genome_db(%d)\n", $genomeDB->dbID);
  printf(" compara(%d) %s : %s : %s\n",
     $genomeDB->taxon_id, $genomeDB->name, $genomeDB->assembly, $genomeDB->genebuild);


  die("ERROR::  db_adaptor not connected to an ensembl-core") unless($genomeDB->db_adaptor);

  my $meta = $genomeDB->db_adaptor->get_MetaContainer;

  my $taxon_id = $meta->get_taxonomy_id;
  my $taxon = $meta->get_Species;

  my $genome_name = $taxon->binomial;
  my ($cs) = @{$genomeDB->db_adaptor->get_CoordSystemAdaptor->fetch_all()};
  my $assembly = $cs->version;
  my $genebuild = $meta->get_genebuild;
  my $core_class = join(" ", $taxon->classification);

  printf(" core   (%d) %s : %s : %s\n", 
     $taxon_id, $genome_name, $assembly, $genebuild);

  unless(($genomeDB->taxon_id == $taxon_id) and
         ($genomeDB->name eq $genome_name) and
         ($genomeDB->assembly eq $assembly) and
         ($genomeDB->genebuild eq $genebuild) 
#	 and ($compara_class eq $core_class)
	 )
  {
    print("=== MISMATCH ===\n\n");
    printf("%s\n%s\n", $compara_class, $core_class);
  }

}


exit(0);

