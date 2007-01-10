#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -dbname ensembl_compara_database
   -port eg 3352 (default)
   -seq_region (e.g. 22)
   -seq_region_start
   -seq_region_end
   -species1 (e.g. \"Homo sapiens\") from which alignments are queried and seq_region refer to
   -assembly1 (e.g. NCBI30) assembly version of species1
   -species2 (e.g. \"Mus musculus\") to which alignments are queried
   -assembly2 (e.g. MGSC3) assembly version of species2
   -alignment_type type of alignment stored e.g. BLASTZ_NET (default: BLASTZ_NET) 
   -conf_file compara_conf_file
              see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
";

my ($host,$dbname);
my $dbuser = 'ensro';
my ($seq_region,$seq_region_start,$seq_region_end);
my ($species1,$assembly1,$species2,$assembly2);
my $conf_file;
my $help = 0;
my $alignment_type = "BLASTZ_NET";
my $limit = 0;
my $port=3352;

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'port=i'  => \$port,
	   'seq_region=s' => \$seq_region,
	   'seq_region_start=i' => \$seq_region_start,
	   'seq_region_end=i' => \$seq_region_end,
	   'species1=s' => \$species1,
	   'assembly1=s' => \$assembly1,
	   'species2=s' => \$species2,
	   'assembly2=s' => \$assembly2,
	   'alignment_type=s' => \$alignment_type,
	   'conf_file=s' => \$conf_file,
           'limit=i' => \$limit);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Connecting to compara database

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -port => $port,
						      -dbname => $dbname,
						      -conf_file => $conf_file);
my $sliceadaptor = $db->get_db_adaptor($species1,$assembly1)->get_SliceAdaptor;


my @seq_regs= @{$sliceadaptor->fetch_all('toplevel')};
foreach my $seq_r(@seq_regs) {
#print STDERR "$seq_region = ".$seq_r->seq_region_name."\n";
#check if needed
if ($seq_region eq $seq_r->seq_region_name) {


my $slice = $sliceadaptor->fetch_by_region($seq_r->coord_system->name,$seq_region);
# further checks on arguments

#print STDERR "$seq_region = ".$seq_r->seq_region_name." is a ".$seq_r->coord_system->name."\n";



unless (defined $seq_region_start) {
  warn "WARNING : setting seq_region_start=1\n";
  $seq_region_start = 1;
}

if ($seq_region_start > $slice->length) {
  warn "seq_region_start $seq_region_start larger than chr_length ".$slice->length."
exit 2\n";
  exit 2;
}
unless (defined $seq_region_end) {
  warn "WARNING : setting seq_region_end=seq_region->length ".$slice->length."\n";
  $seq_region_end = $slice->length;
}
if ($seq_region_end > $slice->length) {
  warn "WARNING : seq_region_end $seq_region_end larger than seq_region->length ".$slice->length."
setting seq_region_end=seq_region->length\n";
  $seq_region_end = $slice->length;
}

my $dafad = $db->get_DnaAlignFeatureAdaptor;

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$dafad->fetch_all_by_species_region($species1,$assembly1,$species2,$assembly2,$seq_region,$seq_region_start,$seq_region_end,$alignment_type,$limit,$seq_r->coord_system->name)};

my $index = 0;

foreach my $ddaf (@DnaDnaAlignFeatures) {
  if ($ddaf->cigar_string eq "") {
    warn $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->score," has no cigar line";
    next;
  }

  my $hstrand; #my $strand;
  my $flip=0;

  $hstrand = "+" if ($ddaf->hstrand > 0);
  $hstrand = "-" if ($ddaf->hstrand < 0);

   if ($hstrand eq "-")  {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hslice->length - $ddaf->hend + 1," ",$ddaf->hslice->length - $ddaf->hstart + 1," ",$hstrand," ",$ddaf->score,"\n";
  } 
 else {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$hstrand," ",$ddaf->score,"\n";
  }
 
  my $sb_seq ;
    $sb_seq = $ddaf->slice->adaptor->fetch_by_region($ddaf->slice->coord_system->name,$ddaf->seqname,$ddaf->start,$ddaf->end)->seq;
  
  
  my $qy_seq;
  if ($ddaf->hstrand > 0) {
    $qy_seq = $ddaf->hslice->adaptor->fetch_by_region($ddaf->hslice->coord_system->name,$ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->seq;
  } else {
    $qy_seq = $ddaf->hslice->adaptor->fetch_by_region($ddaf->hslice->coord_system->name,$ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->invert->seq;
  }
  ($sb_seq,$qy_seq) = make_gapped_align_from_cigar_string($sb_seq,$qy_seq,$ddaf->cigar_string);
  print lc $sb_seq,"\n";
  print lc $qy_seq,"\n";
  print "\n";
  $index++;
}
}
}

sub make_gapped_align_from_cigar_string {
    my ($ungapped_query, $ungapped_subject, $Cigar_string) = @_;
    my $query = '';
    my $subject = '';

    my @pieces = ( $Cigar_string =~ /(\d*[MDI])/g );
    unless (@pieces) {
        print STDERR "Error parsing cigar_string\n";
    }
    foreach my $piece (@pieces) {
        my ($length) = ( $piece =~ /^(\d*)/ );
	unless (defined $length) {
	  $length = 1;
	}
	if (defined $length && $length eq "") {
	  $length = 1;
	}
        if ($piece =~ /M$/) {
            $query .= substr($ungapped_query, 0, $length);
            $subject .= substr($ungapped_subject, 0, $length);
            $ungapped_query = substr($ungapped_query, $length);
            $ungapped_subject = substr($ungapped_subject, $length);
        }
        elsif ($piece =~ /D$/) {
            $query .= '-' x $length;
            $subject .= substr($ungapped_subject, 0, $length);
            $ungapped_subject = substr($ungapped_subject, $length);
        }
        elsif ($piece =~ /I$/) {
            $subject .= '-' x $length;
            $query .= substr($ungapped_query, 0, $length);
            $ungapped_query = substr($ungapped_query, $length);
        }
        else {
            print STDERR "Error reconstructing alignment\n";
        }

    }
    unless (length($query) == length($subject)) {
        warn "Reconstructed HSP seqs are of unequal length\n";
    }
    return ($query, $subject);
}

exit 0;
