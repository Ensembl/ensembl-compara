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

my $genomes = $comparaDBA->get_GenomeDBAdaptor->fetch_all;
foreach my $genomeDB (@{$genomes}) {

  #skip ancestral sequences which have no entry in core dbs
  next if ($genomeDB->name eq "ancestral_sequences");

  printf("genome_db(%d)\n", $genomeDB->dbID);
  printf(" compara(%d) %s : %s : %s\n",
     $genomeDB->taxon_id, $genomeDB->name, $genomeDB->assembly, $genomeDB->genebuild);


  die("ERROR::  db_adaptor not connected to an ensembl-core") unless($genomeDB->db_adaptor);

  my $meta = $genomeDB->db_adaptor->get_MetaContainer;

  my $taxon_id = $meta->get_taxonomy_id;
  my $taxon = $meta->get_Species;
  my $genome_name = $meta->get_production_name;

  my ($cs) = @{$genomeDB->db_adaptor->get_CoordSystemAdaptor->fetch_all()};
  my $assembly = $cs->version;
  my $genebuild = $meta->get_genebuild;

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
    printf("taxon_id compara=%d core=%d\n", $genomeDB->taxon_id, $taxon_id);
    printf("name compara=%s core=%s\n", $genomeDB->name, $genome_name);
    printf("assembly compara=%s core=%s\n", $genomeDB->assembly, $assembly);
    printf("genebuild compara=%s core=%s\n", $genomeDB->genebuild, $genebuild);

  }

}


exit(0);

