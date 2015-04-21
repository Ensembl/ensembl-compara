#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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
use Getopt::Long;

my $usage = "
$0
  [--help]                      this menu
   --dbname string              (e.g. ensembl_compara_45) one of the compara database Bio::EnsEMBL::Registry aliases
   --seq_region string          (e.g. 2X)
   --qy string                  (e.g. \"Drosophila melanogaster\") the query species
                                from which alignments are queried and seq_region refer to
   --tg string                  (e.g. \"Anopheles gambiae\") the target sepcies
                                to which alignments are queried
  [--ortholog_type string]      (e.g. ortholog_one2one) types of orthologs to extract (comma separated)
  [--reg_conf filepath]         the Bio::EnsEMBL::Registry configuration file. If none given,
                                the one set in ENSEMBL_REGISTRY will be used if defined, if not
";

my $help = 0;
my $dbname;
my $ortholog_type = "ortholog_one2one";
my $seq_region;
my $qy_species;
my $tg_species;
my $reg_conf;

my $method_link_type = "ENSEMBL_ORTHOLOGUES";

GetOptions('help' => \$help,
         'dbname=s' => \$dbname,
         'seq_region=s' => \$seq_region,
         'qy=s' => \$qy_species,
         'tg=s' => \$tg_species,
         'ortholog_type=s' => \$ortholog_type,
           'reg_conf=s' => \$reg_conf);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}


#Print arguments
print STDERR "Looking for $ortholog_type between $qy_species and $tg_species.\n" ;

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');
my $ha = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'Homology');

my $qy_gdb = $gdba->fetch_by_registry_name($qy_species);
my $tg_gdb = $gdba->fetch_by_registry_name($tg_species);
my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$qy_gdb, $tg_gdb]);


my @A_ortholog_types = split(",", $ortholog_type) ;
foreach my $ortho_type (@A_ortholog_types) {
  print STDERR "\nStarting with =$ortho_type= and =".$mlss->name()."=\n" ;

  #Get all homologies
  #my $homols = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss, -orthology_type => 'ortholog_one2one');
  my $homols = $ha->fetch_all_by_MethodLinkSpeciesSet($mlss, -orthology_type => $ortho_type);

  #For each members
  my %gff;

  while (my $homol = shift @{$homols}) {

      my $Q_chr_start; my $Q_chr_end; my $Q_chr_std; my $Q_chr_name;
      my $T_chr_start; my $T_chr_end; my $T_chr_std; my $T_chr_name;
      my $score = 1 ;

      #print "=== TEST NEW HOMOLOGY! ===\n" ;
      foreach my $member (@{$homol->get_all_Members}) {

      #Get the "query" member and the "target" member
      my $genom = $member->genome_db->name() ;
      #print "\tCurrent genome: $genom\n" ;
      #print "\tSpecies: $qy_species [Q] & $tg_species [T]\n" ;

      if ($genom eq $qy_species) {
        $Q_chr_start = $member->dnafrag_start();
        $Q_chr_end = $member->dnafrag_end();
        $Q_chr_std = $member->dnafrag_strand();
        $Q_chr_name = $member->dnafrag->name();
      } elsif ($genom eq $tg_species) {
        $T_chr_start = $member->dnafrag_start();
        $T_chr_end = $member->dnafrag_end();
        $T_chr_std = $member->dnafrag_strand();
        $T_chr_name = $member->dnafrag->name();
      } else {
        print STDERR "WARNING!! This genome is neither QUERY nor SPECIES!\n" ;
      }
      }

      #Deal with the strands
      if ($Q_chr_std == "-1") {
        $Q_chr_std *= -1 ;
        $T_chr_std *= -1 ;
      }

      #Print all the stuff
      if ($Q_chr_name && $Q_chr_start && $Q_chr_end && $score && $Q_chr_std && $T_chr_name && $T_chr_start && $T_chr_end && $T_chr_std) {
        $gff{$Q_chr_name}{$T_chr_name} .= "$Q_chr_name\tsynteny\tsimilarity\t$Q_chr_start\t$Q_chr_end\t$score\t$Q_chr_std\t.\t$T_chr_name\t$T_chr_start\t$T_chr_end\t$T_chr_std\t.\n";
      }
    }
    foreach my $chr1 (sort keys %gff) {
      open SYN,">>$chr1.syten.gff";
      foreach my $chr2 (sort keys %{$gff{$chr1}}) {
        print SYN $gff{$chr1}{$chr2};
      }
      close SYN;
    }
}
exit 0;
