#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Getopt::Long;

my $usage = "
$0
  [--help]                      this menu
   --dbname string              (e.g. compara23) one of the compara database Bio::EnsEMBL::Registry aliases
   --seq_region string          (e.g. 22)
   --qy string                  (e.g. human) the query species (i.e. a Bio::EnsEMBL::Registry alias)
                                from which alignments are queried and seq_region refer to
   --tg string                  (e.g. mouse) the target sepcies (i.e. a Bio::EnsEMBL::Registry alias)
                                to which alignments are queried
  [--alignment_type string]     (e.g. TRANSLATED_BLAT) type of alignment stored (default: BLASTZ_NET)
  [--reg_conf filepath]         the Bio::EnsEMBL::Registry configuration file. If none given, 
                                the one set in ENSEMBL_REGISTRY will be used if defined, if not
  [--level interger]            highest level to be dumped
";

my $help = 0;
my $dbname;
my $alignment_type = "BLASTZ_NET";
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
	   'alignment_type=s' => \$alignment_type,
           'level=s' => \$level,
           'reg_conf=s' => \$reg_conf);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

print STDERR "Start time when dumping gff for synteny on chr $seq_region : " . time . "\n";

my $dafa = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'DnaAlignFeature');
my $sa = Bio::EnsEMBL::Registry->get_adaptor($qy_species, 'core', 'Slice');

my $tg_binomial = Bio::EnsEMBL::Registry->get_adaptor($tg_species,'core','MetaContainer')->get_Species->binomial;

my $slice = $sa->fetch_by_region('toplevel',$seq_region);
my $seq_region_length = $slice->length;
my $coord_system_name = $slice->coord_system->name;

my $start = 1;
my $chunk = 5000000;

open SYN,"|sort -u > $seq_region.syten.gff";

while ($start <= $seq_region_length) {
  my $end = $start + $chunk -1;
  $end = $seq_region_length if ($end > $seq_region_length);
  
  $slice = $sa->fetch_by_region($coord_system_name, $seq_region, $start, $end);
  
  my $dafs = $dafa->fetch_all_by_Slice($slice, $tg_binomial,undef,$alignment_type);
  print STDERR "Got ", scalar @{$dafs}," features for chunk $start to $end on chr $seq_region\n";
  
  foreach my $daf (@{$dafs}) {
    
    my ($strand,$hstrand) = qw(+ +);
    $strand = "-" if ($daf->strand < 0);
    $hstrand = "-" if ($daf->hstrand < 0);
    
    # keep on the basis of level_id
    next if ($daf->level_id != $level);
    
    # print out a in gff format
    print SYN  
      $daf->seqname . "\t" .
        "synteny\t" .
          "similarity\t" .
            $daf->seq_region_start . "\t" .
              $daf->seq_region_end . "\t" .
                $daf->score . "\t" .
                  $strand . "\t" .
                    ".\t" .
                      $daf->hseqname . "\t" .
                        $daf->hstart . "\t" .
                          $daf->hend . "\t" .
                            $hstrand . "\t" .
                              ".\n";
  }
  $start += $chunk;
}

close SYN;

print STDERR "End time when dumping gff for synteny on chr $seq_region " . time . "\n";
