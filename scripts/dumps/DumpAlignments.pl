#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
#use Bio::SimpleAlign;
use Bio::AlignIO;
#use Bio::LocatableSeq;

use Getopt::Long;

#Bio::EnsEMBL::Registry->load_all("/nfs/acari/abel/.Registry.conf");

my $usage = "
$0 [-help]
   --dbname ensembl_compara_database
   --seq_region (e.g. 22)
   --seq_region_start (e.g. 50000000)
   --seq_region_end (e.g. 50500000)
   --qy (e.g. human) the query species (or Registry alias) from which alignments are queried and seq_region refer to
   --tg (e.g. mouse) the target sepcies (or Registry alias) to which alignments are queried
   --alignment_type type of alignment stored e.g. BLASTZ_NET (default: BLASTZ_NET)
   --ft alignment format, available in bioperl Bio::AlignIO (default: clustalw)
   --limit (e.g. 2) limit the output to the number of alignments specified
   --reg_conf the Bio::EnsEMBL::Registry configuration file. If none given, 
              the one set in ENSEMBL_REGISTRY will be used if defined, if not
              ~/.ensembl_init will be used.
";

my $dbname;
my ($seq_region,$seq_region_start,$seq_region_end);
my ($qy_species,$tg_species);
my $help = 0;
my $alignment_type = "BLASTZ_NET";
my $limit;
my $reg_conf;
my $format = "clustalw";

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'seq_region=s' => \$seq_region,
	   'seq_region_start=i' => \$seq_region_start,
	   'seq_region_end=i' => \$seq_region_end,
	   'qy=s' => \$qy_species,
	   'tg=s' => \$tg_species,
	   'alignment_type=s' => \$alignment_type,
           'ft=s' => \$format,
           'limit=i' => \$limit,
           'reg_conf=s' => \$reg_conf);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

if (defined $reg_conf) {
  Bio::EnsEMBL::Registry->load_all($reg_conf);
}

my $qy_sa = Bio::EnsEMBL::Registry->get_adaptor($qy_species,'core','Slice');
my $qy_slice = $qy_sa->fetch_by_region('toplevel',$seq_region,$seq_region_start,$seq_region_end);

my $tg_binomial = Bio::EnsEMBL::Registry->get_adaptor($tg_species,'core','MetaContainer')->get_Species->binomial;

my $dafad = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','DnaAlignFeature');

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$dafad->fetch_all_by_Slice($qy_slice,$tg_binomial,undef,$alignment_type,$limit)};

my $index = 0;

foreach my $ddaf (@DnaDnaAlignFeatures) {

  if ($ddaf->cigar_string eq "") {
    warn $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->score," has no cigar line";
    next;
  }

  unless ($format eq "axt") {
    my $sa = $ddaf->get_SimpleAlign($ddaf);

    my $alignIO = Bio::AlignIO->newFh(-interleaved => 0,
                                      -fh => \*STDOUT,
                                      -format => $format,
                                      -idlength => 20);
    print $alignIO $sa;
  } else {
    print_out_axt($ddaf);
    $index++;
  }
}

sub print_out_axt {
  my $ddaf = shift;

  print $index . " " .
    $ddaf->seqname . " " .
      $ddaf->seq_region_start . " " .
        $ddaf->seq_region_end . " " .
          $ddaf->hseqname . " ";

  if ($ddaf->hstrand < 0)  {
    my $hstrand = "-";
    print $ddaf->hslice->length - $ddaf->hseq_region_end + 1 . " " .
      $ddaf->hslice->length - $ddaf->hseq_region_start + 1 . " " .
                  $hstrand . " " .
                    $ddaf->score,"\n";
  } else {
    my $hstrand = "+";
    print $ddaf->hseq_region_start . " " .
      $ddaf->hseq_region_end . " ";
  }

  print $ddaf->score,"\n";

  my ($sb_seq,$qy_seq) = @{$ddaf->alignment_strings};

  print lc $sb_seq,"\n";
  print lc $qy_seq,"\n";
  print "\n";
}

exit 0;
