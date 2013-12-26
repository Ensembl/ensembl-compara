#!/usr/bin/env perl
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


use strict;
use warnings;

use Bio::EnsEMBL::Registry;


#
# This script checks a registry conf file by accessing the refered Compara
# database and all its related core databases
#

my $reg_conf = shift;
die("must specify registry conf file on commandline\n") unless($reg_conf);

Bio::EnsEMBL::Registry->load_all($reg_conf);


my $comparaDBA  = Bio::EnsEMBL::Registry->get_DBAdaptor('Multi', 'compara');

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

