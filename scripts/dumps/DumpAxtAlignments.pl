#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -dbname ensembl_compara_database
   -chr_name (e.g. 22)
   -chr_start
   -chr_end
   -species1 (e.g. \"Homo sapiens\") from which alignments are queried and chr_name refer to
   -assembly1 (e.g. NCBI30) assembly version of species1
   -species2 (e.g. \"Mus musculus\") to which alignments are queried
   -assembly2 (e.g. MGSC3) assembly version of species2
   -alignment_type type of alignment stored e.g. WGA (default: WGA) 
   -conf_file compara_conf_file
              see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
";

my ($host,$dbname);
my $dbuser = 'ensro';
my ($chr_name,$chr_start,$chr_end);
my ($species1,$assembly1,$species2,$assembly2);
my $conf_file;
my $help = 0;
my $alignment_type = "WGA";

unless (scalar @ARGV) {
  print $usage;
  exit 0;
}

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'chr_name=s' => \$chr_name,
	   'chr_start=i' => \$chr_start,
	   'chr_end=i' => \$chr_end,
	   'species1=s' => \$species1,
	   'assembly1=s' => \$assembly1,
	   'species2=s' => \$species2,
	   'assembly2=s' => \$assembly2,
	   'alignment_type=s' => \$alignment_type,
	   'conf_file=s' => \$conf_file);

$|=1;

if ($help) {
  print $usage;
  exit 0;
}

# Connecting to compara database

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -dbname => $dbname,
						      -conf_file => $conf_file);

my $species1_dbadaptor = $db->get_db_adaptor($species1,$assembly1);
my $sb_chradp = $species1_dbadaptor->get_ChromosomeAdaptor;
my $chr = $sb_chradp->fetch_by_chr_name($chr_name);

my $species2_dbadaptor = $db->get_db_adaptor($species2,$assembly2);
my $qy_chradp = $species2_dbadaptor->get_ChromosomeAdaptor;
my $qy_chrs = $qy_chradp->fetch_all;

my %qy_chrs;

foreach my $qy_chr (@{$qy_chrs}) {
  $qy_chrs{$qy_chr->chr_name} = $qy_chr;
}

# futher checks on arguments

unless (defined $chr_start) {
  warn "WARNING : setting chr_start=1\n";
  $chr_start = 1;
}

if ($chr_start > $chr->length) {
  warn "chr_start $chr_start larger than chr_length ".$chr->length."
exit 1\n";
  exit 1;
}
unless (defined $chr_end) {
  warn "WARNING : setting chr_end=chr_length ".$chr->length."\n";
  $chr_end = $chr->length;
}
if ($chr_end > $chr->length) {
  warn "WARNING : chr_end $chr_end larger than chr_length ".$chr->length."
setting chr_end=chr_length\n";
  $chr_end = $chr->length;
}

my $species1_sliceadaptor = $species1_dbadaptor->get_SliceAdaptor;
my $species2_sliceadaptor = $species2_dbadaptor->get_SliceAdaptor;

my $dafad = $db->get_DnaAlignFeatureAdaptor;

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$dafad->fetch_all_by_species_region($species1,$assembly1,$species2,$assembly2,$chr_name,$chr_start,$chr_end,$alignment_type)};

my $index = 0;

foreach my $ddaf (@DnaDnaAlignFeatures) {
  
  if ($ddaf->cigar_string eq "") {
    warn $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->score," has no cigar line";
    next;
  }

  my $hstrand;
  $hstrand = "+" if ($ddaf->hstrand > 0);
  $hstrand = "-" if ($ddaf->hstrand < 0);

  if ($hstrand eq "-") {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$qy_chrs{$ddaf->hseqname}->length - $ddaf->hend + 1," ",$qy_chrs{$ddaf->hseqname}->length - $ddaf->hstart + 1," ",$hstrand," ",$ddaf->score,"\n";
  } else {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$hstrand," ",$ddaf->score,"\n";
  }
  my $sb_seq = $species1_sliceadaptor->fetch_by_chr_start_end($ddaf->seqname,$ddaf->start,$ddaf->end)->seq;
  my $qy_seq;
  if ($ddaf->hstrand > 0) {
    $qy_seq = $species2_sliceadaptor->fetch_by_chr_start_end($ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->seq;
  } else {
    $qy_seq = $species2_sliceadaptor->fetch_by_chr_start_end($ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->invert->seq;
  }
  ($sb_seq,$qy_seq) = make_gapped_align_from_cigar_string($sb_seq,$qy_seq,$ddaf->cigar_string);
  print lc $sb_seq,"\n";
  print lc $qy_seq,"\n";
  print "\n";
  $index++;
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
