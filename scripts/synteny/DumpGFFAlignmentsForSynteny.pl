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
my @karyotype_coord_system_names = ('chromosome', 'group');

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
unless (defined $seq_region) {
  foreach my $n ($ref_coord_system_name ? ($ref_coord_system_name) : @karyotype_coord_system_names) {
    push @$qy_dnafrags, @{$dfa->fetch_all_by_GenomeDB_region($qy_gdb, $n)};
  }
} else {
  $qy_dnafrags = [ $dfa->fetch_by_GenomeDB_and_name($qy_gdb, $seq_region) ];
}

my %qy_karyotypes = map {$_->seq_region_name => 1} @{$qy_gdb->db_adaptor->get_SliceAdaptor->fetch_all_karyotype()};
my %tg_karyotypes = map {$_->seq_region_name => 1} @{$tg_gdb->db_adaptor->get_SliceAdaptor->fetch_all_karyotype()};

$qy_gdb->db_adaptor->dbc->disconnect_if_idle;
$tg_gdb->db_adaptor->dbc->disconnect_if_idle;

foreach my $qy_dnafrag (@{$qy_dnafrags}) {
  #Check if the dnafrag is part of the karyotype to decide whether to calculate the synteny

  next unless ($qy_karyotypes{$qy_dnafrag->name} || $force);

  my $seq_region_name = $qy_dnafrag->name;
  open(my $synt_file, ">", "${output_dir}/${seq_region_name}.syten.gff");

  my $tg_dnafrags;
  foreach my $n ($non_ref_coord_system_name ? ($non_ref_coord_system_name) : @karyotype_coord_system_names) {
    push @$tg_dnafrags, @{$dfa->fetch_all_by_GenomeDB_region($tg_gdb, $n)};
  }

  foreach my $tg_dnafrag (@$tg_dnafrags) {
    #Check if the dnafrag is part of the karyotype to decide whether to calculate the synteny
    next unless ($tg_karyotypes{$tg_dnafrag->name} || $force);

    my $start = 1;
    my $chunk = 5000000;

    while ($start <= $qy_dnafrag->length) {
      my $end = $start + $chunk -1;
      $end = $qy_dnafrag->length if ($end > $qy_dnafrag->length);

      my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag($mlss,$qy_dnafrag,$start,$end,$tg_dnafrag);
      while (my $gab = shift @{$gabs}) {
        my $qy_ga = $gab->reference_genomic_align;
        
        # keep on the basis of level_id
        next if ($level and ($gab->level_id > $level));
        
        my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};
        
        my ($strand,$hstrand) = qw(+ +);
        
        if ($qy_ga->dnafrag_strand > 0 && $tg_ga->dnafrag_strand < 0) {
          $hstrand = "-";
        }
        if ($qy_ga->dnafrag_strand < 0 && $tg_ga->dnafrag_strand > 0) {
          $hstrand = "-";
        }
        
        # print out a in gff format
        print $synt_file join("\t",
            $qy_dnafrag->name,
            'synteny',
            'similarity',
            $qy_ga->dnafrag_start,
            $qy_ga->dnafrag_end,
            $gab->score,
            $strand,
            '.',
            $tg_dnafrag->name,
            $tg_ga->dnafrag_start,
            $tg_ga->dnafrag_end,
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
