#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $usage = "
$0
  [--help]                      this menu
   --dbname string              (e.g. compara23) one of the compara database Bio::EnsEMBL::Registry aliases
   --seq_region string          (e.g. 22)
   --qy string                  (e.g. \"Homo sapiens\") the query species
                                from which alignments are queried and seq_region refer to
   --tg string                  (e.g. \"Mus musculus\") the target sepcies
                                to which alignments are queried
  [--method_link_type string]   (e.g. TRANSLATED_BLAT) type of alignment stored (default: BLASTZ_NET)
  [--reg_conf filepath]         the Bio::EnsEMBL::Registry configuration file. If none given, 
                                the one set in ENSEMBL_REGISTRY will be used if defined, if not
  [--level interger]            highest level to be dumped
";

my $help = 0;
my $dbname;
my $method_link_type = "BLASTZ_NET";
my $seq_region;
my $qy_species;
my $tg_species;
my $level = 1;
my $reg_conf;

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'seq_region=s' => \$seq_region,
	   'qy=s' => \$qy_species,
	   'tg=s' => \$tg_species,
	   'method_link_type=s' => \$method_link_type,
           'level=s' => \$level,
           'reg_conf=s' => \$reg_conf);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'MethodLinkSpeciesSet');
my $dfa = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'DnaFrag');
my $gaba = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomicAlignBlock');

my $qy_gdb = $gdba->fetch_by_name_assembly($qy_species);
my $tg_gdb = $gdba->fetch_by_name_assembly($tg_species);
my $mlss = $mlssa->fetch_by_method_link_type_GenomeDBs($method_link_type, [$qy_gdb, $tg_gdb]);

my $qy_dnafrags;
unless (defined $seq_region) {
  $qy_dnafrags = $dfa->fetch_all_by_GenomeDB_region($qy_gdb, 'chromosome');
} else {
  $qy_dnafrags = [ $dfa->fetch_by_GenomeDB_and_name($qy_gdb, $seq_region) ];
}

foreach my $qy_dnafrag (@{$qy_dnafrags}) {
  next unless ($qy_dnafrag->name =~ /^\d+[A-Za-z]*$|^W$|^X\d?$|^Y$|^Z$/);
  my $seq_region_name = $qy_dnafrag->name;
  open SYN,">$seq_region_name.syten.gff";

  foreach my $tg_dnafrag (@{$dfa->fetch_all_by_GenomeDB_region($tg_gdb, 'chromosome')}) {
    next unless ($tg_dnafrag->name =~ /^\d+[A-Za-z]*$|^W$|^X\d?$|^Y$|^Z$/);

    my $start = 1;
    my $chunk = 5000000;

    while ($start <= $qy_dnafrag->length) {
      my $end = $start + $chunk -1;
      $end = $qy_dnafrag->length if ($end > $qy_dnafrag->length);

      my $gabs = $gaba->fetch_all_by_MethodLinkSpeciesSet_DnaFrag_DnaFrag($mlss,$qy_dnafrag,$start,$end,$tg_dnafrag);
      while (my $gab = shift @{$gabs}) {
        my $qy_ga = $gab->reference_genomic_align;
        
        # keep on the basis of level_id
        next if ($level and ($qy_ga->level_id > $level));
        
        my ($tg_ga) = @{$gab->get_all_non_reference_genomic_aligns};
        
        my ($strand,$hstrand) = qw(+ +);
        
        if ($qy_ga->dnafrag_strand > 0 && $tg_ga->dnafrag_strand < 0) {
          $hstrand = "-";
        }
        if ($qy_ga->dnafrag_strand < 0 && $tg_ga->dnafrag_strand > 0) {
          $hstrand = "-";
        }
        
        # print out a in gff format
        print SYN  
          $qy_dnafrag->name . "\t" .
            "synteny\t" .
              "similarity\t" .
                $qy_ga->dnafrag_start . "\t" .
                  $qy_ga->dnafrag_end . "\t" .
                    $gab->score . "\t" .
                      $strand . "\t" .
                        ".\t" .
                          $tg_dnafrag->name . "\t" .
                            $tg_ga->dnafrag_start . "\t" .
                              $tg_ga->dnafrag_end . "\t" .
                                $hstrand . "\t" .
                                  ".\n";
      }
      $start += $chunk;
    }
  }
  close SYN;
}

exit 0;
