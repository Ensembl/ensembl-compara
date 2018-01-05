#!/usr/bin/env perl
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


use strict;
use warnings;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Analysis;
use Getopt::Long;

my $usage = "
getsynteny.pl  --host ensembldb.ensembl.org
               --user anonymous
               --dbname ensembl_compara_41
               --chr_names \"22\"
               --species1 \"Homo sapiens\"
               [--assembly1 NCBI30]
               --species2 \"Mus musculus\"
               [--assembly2 MGSC3]
               [--method_link_type SYNTENY]

$0 [--help]
   --host               compara_db_host_server (default = 'ensembldb.ensembl.org')
   --user               username (default = 'anonymous')
   --dbname             compara_database_name (default = 'ensembl_compara_41')
   --chr_names          \"20,21,22\" (default = \"all\")
   --species1           from which alignments are queried and chr_names
                        refer to (e.g. \"Homo sapiens\" is default) 
   [--assembly1]        assembly version of species1 (e.g. NCBI36, default is undef)
   --species2           to which alignments are queried (e.g. \"Mus musculus\" is default)
   [--assembly2]        assembly version of species2 (e.g. NCBIM36, default is undef)
   [--method_link_type] (default = 'SYNTENY')


";

my $help = 0;
my $host = 'ensembldb.ensembl.org';
my $user = 'anonymous';
my $pass;
my $dbname = 'ensembl_compara_41';
my $port = 3306;

my $species1 = 'Homo sapiens';
my $species1_assembly;
my $species2 = 'Mus musculus';
my $species2_assembly;
my $method_link_type = "SYNTENY";

my $chr_names = "all";

$| = 1;

&GetOptions('help' => \$help,
            'host:s' => \$host,
	    'port:i' => \$port,
            'user:s' => \$user,
            'dbname:s' => \$dbname,
            'pass:s' => \$pass,
            'species1:s' => \$species1,
            'assembly1:s' => \$species1_assembly,
            'species2:s' => \$species2,
            'assembly2:s' => \$species2_assembly,
            'chr_names=s' => \$chr_names,
            'method_link_type=s' => \$method_link_type);

if ($help) {
  print $usage;
  exit 0;
}

my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host        => $host,
						       -port        => $port,
                                                       -user        => $user,
                                                       -pass        => $pass,
                                                       -dbname      => $dbname);

my $gdba = $dba->get_GenomeDBAdaptor;
my $dfa = $dba->get_DnaFragAdaptor;
my $mlssa = $dba->get_MethodLinkSpeciesSetAdaptor;
my $sra = $dba->get_SyntenyRegionAdaptor;

my $gdb1 = $gdba->fetch_by_name_assembly($species1,$species1_assembly);
my $gdb2 = $gdba->fetch_by_name_assembly($species2,$species2_assembly);

my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$gdb1, $gdb2]);

my $dfgs;

if (defined $chr_names and $chr_names ne "all") {
  my @chr_names = split /,/, $chr_names;
  foreach my $chr_name (@chr_names) {
    push @{$dfgs}, $dfa->fetch_by_GenomeDB_and_name($gdb1, $chr_name);
  }
} else {
  $dfgs = $dfa->fetch_all_by_GenomeDB_region($gdb1);
}

my $total_nb_syntenies = 0;
foreach my $df (@{$dfgs}) {
  my $syntenies = $sra->fetch_all_by_MethodLinkSpeciesSet_DnaFrag($mlss, $df);

  next unless (scalar @{$syntenies});
  print STDERR "For DnaFrag ".$df->name.", length ",$df->length,", ";
  print STDERR "got features " . scalar @{$syntenies} . "\n";
  $total_nb_syntenies += scalar @{$syntenies};

  my $dfname = $df->name;

  foreach my $sr (@{$syntenies}) {
    my ($species1_dfr_string, $species2_dfr_string);
    foreach my $dfr (@{$sr->get_all_DnaFragRegions}) {
      my $strand = "+";

      if ($dfr->dnafrag_strand < 0) {
        $strand = "-";
      }
      if ($dfr->dnafrag->genome_db->name eq $species1) {
        $species1_dfr_string = $dfr->dnafrag->name . "\t" .
          "synteny\t" .
          "similarity\t" .
          $dfr->dnafrag_start . "\t" .
          $dfr->dnafrag_end . "\t" .
          "0.0" . "\t" .
          $strand . "\t" .
          ".\t" ;
      } elsif ($dfr->dnafrag->genome_db->name eq $species2) {
        $species2_dfr_string = $dfr->dnafrag->name . "\t" .
          $dfr->dnafrag_start . "\t" .
          $dfr->dnafrag_end . "\t" .
          $strand . "\t" .
          ".\n";
      }
    }
    print $species1_dfr_string . $species2_dfr_string;
  }
}

print STDERR "Total number of_synteny regions $total_nb_syntenies\n";
