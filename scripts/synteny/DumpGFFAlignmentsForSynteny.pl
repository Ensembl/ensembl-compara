#!/usr/bin/env perl
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


use warnings;
use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $usage = "
$0
  [--help]                      this menu
   --dbname string              (e.g. compara23) one of the compara database Bio::EnsEMBL::Registry aliases or a valid url
   --seq_region string          (e.g. 22)
   --qy string                  (e.g. \"Homo sapiens\") the query species
                                from which alignments are queried and seq_region refer to
  [--tg string]                  (e.g. \"Mus musculus\") the target sepcies
                                to which alignments are queried
  [--method_link_species_set_id] method_link_species_set id of the pairwise alignments. Used to automatically determine the tg name
  [--method_link_type string]   (e.g. TRANSLATED_BLAT) type of alignment stored (default: BLASTZ_NET)
  [--reg_conf filepath]         the Bio::EnsEMBL::Registry configuration file. If none given, 
                                the one set in ENSEMBL_REGISTRY will be used if defined, if not
  [--level interger]            highest level to be dumped
  [--force 0|1]                 Set to true to over-ride the check on the slice for has_karyotype. Default 0.
  [--output_dir path]           location to write output files
";

my $help = 0;
my $dbname;
my $method_link_type = "LASTZ_NET";
my $mlss_id;
my $seq_region;
my $qy_species;
my $tg_species;
my $level = 1;
my $reg_conf;
my $force = 0; #use slice even if it has no karyotype
my $output_dir = "";
my $ref_coord_system_name = undef;
my $non_ref_coord_system_name = undef;
my $genome_dumps_dir = $ENV{'COMPARA_HPS'} . '/genome_dumps/';

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'seq_region=s' => \$seq_region,
	   'qy=s' => \$qy_species,
	   'tg=s' => \$tg_species,
	   'method_link_type=s' => \$method_link_type,
	   'method_link_species_set=i' => \$mlss_id,
           'level=s' => \$level,
           'reg_conf=s' => \$reg_conf,
           'force' => \$force,
           'ref_coord_system_name:s' => \$ref_coord_system_name,
           'non_ref_coord_system_name:s' => \$non_ref_coord_system_name,
           'output_dir=s' => \$output_dir);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->no_version_check(1);

my $compara_dba;
if ($reg_conf) {
    Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");
}

if ($dbname =~ /mysql:\/\//) {
    $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$dbname);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname, "compara");
}
die "Cannot connect to compara database: $dbname\n" if (!$compara_dba);

my $gdba = $compara_dba->get_GenomeDBAdaptor;
$gdba->dump_dir_location($genome_dumps_dir);
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
my $dfa = $compara_dba->get_DnaFragAdaptor;
my $gaba = $compara_dba->get_GenomicAlignBlockAdaptor;

my $qy_gdb = $gdba->fetch_by_name_assembly($qy_species);

my $mlss;
my $tg_gdb;
if ($mlss_id) {
    $mlss = $mlssa->fetch_by_dbID($mlss_id);
    my $found_query = 0;
    #find target gdb from mlss
    foreach my $genome_db (@{$mlss->species_set->genome_dbs}) {
        if ($qy_gdb->name ne $genome_db->name) {
            $tg_gdb = $genome_db;
        } else {
            $found_query = 1;
        }
    }
    unless ($found_query) {
        die "Unable to find query species $qy_species in this method_link_species_set $mlss_id " . $mlss->name;
    }
} else {
    $tg_gdb = $gdba->fetch_by_name_assembly($tg_species);
    $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$qy_gdb, $tg_gdb]);
}

my $qy_dnafrags;
if ($seq_region) {
  $qy_dnafrags = [ $dfa->fetch_by_GenomeDB_and_name($qy_gdb, $seq_region) ];
} elsif ($force) {
  $qy_dnafrags = $dfa->fetch_all_by_GenomeDB($qy_gdb);
} else {
  $qy_dnafrags = $dfa->fetch_all_karyotype_DnaFrags_by_GenomeDB($qy_gdb);
}
$qy_gdb->db_adaptor->dbc->disconnect_if_idle;

my $tg_dnafrags;
if ($force) {
  $tg_dnafrags = $dfa->fetch_all_by_GenomeDB($tg_gdb);
} else {
  $tg_dnafrags = $dfa->fetch_all_karyotype_DnaFrags_by_GenomeDB($tg_gdb);
}
$tg_gdb->db_adaptor->dbc->disconnect_if_idle;

foreach my $qy_dnafrag (@{$qy_dnafrags}) {

  my $seq_region_name = $qy_dnafrag->name;
  open(my $synt_file, ">", "${output_dir}/${seq_region_name}.syten.gff");

  foreach my $tg_dnafrag (@$tg_dnafrags) {

    my $start = 1;
    my $chunk = 5000000;

    while ($start <= $qy_dnafrag->length) {
      my $end = $start + $chunk -1;
      $end = $qy_dnafrag->length if ($end > $qy_dnafrag->length);

      my $aln_coords = $gaba->_alignment_coordinates_on_regions($mlss->dbID,
          $qy_dnafrag->dbID, $start, $end,
          $tg_dnafrag->dbID, 1, $tg_dnafrag->length,
          "ga1.genomic_align_block_id, ga1.dnafrag_start, ga1.dnafrag_end, ga1.dnafrag_strand, ga2.dnafrag_start, ga2.dnafrag_end, ga2.dnafrag_strand"
      );

      foreach my $aln ( @$aln_coords ) {
          my ( $gab_id, $qy_start, $qy_end, $qy_strand, $tg_start, $tg_end, $tg_strand ) = @$aln;
          my $gab = $gaba->fetch_by_dbID($gab_id);

          # keep on the basis of level_id
          next if ($level and ($gab->level_id > $level));

          my ($strand,$hstrand) = qw(+ +);
        
          $hstrand = "-" if ( ($qy_strand > 0 && $tg_strand < 0) || ($qy_strand < 0 && $tg_strand > 0) );
          
          # print out a in gff format
          print $synt_file join("\t",
              $qy_dnafrag->name,
              'synteny',
              'similarity',
              $qy_start,
              $qy_end,
              $gab->score,
              $strand,
              '.',
              $tg_dnafrag->name,
              $tg_start,
              $tg_end,
              $hstrand,
              '.',
          ), "\n";
      }

      $start += $chunk;
    }
  }
  close $synt_file;
}

exit 0;
