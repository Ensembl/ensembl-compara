#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;

my ($host,$dbname,$dbuser,$chr_name,$chr_start,$chr_end,$sb_species,$qy_species,$dnafrag_type);

GetOptions('host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'chr_name=s' => \$chr_name,
	   'chr_start=i' => \$chr_start,
	   'chr_end=i' => \$chr_end,
	   'sb_species=s' => \$sb_species,
	   'qy_species=s' => \$qy_species,
	   'dnafrag_type=s' => \$dnafrag_type);

# Connecting to compara database

unless (defined $dbuser) {
  $dbuser = 'ensro';
}

$|=1;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host => $host,
						      -user => $dbuser,
						      -dbname => $dbname);

my $gdbadp = $db->get_GenomeDBAdaptor;


my $sb_species_dbadaptor = $gdbadp->fetch_by_species_tag($sb_species)->db_adaptor;

my $sb_chradp = $sb_species_dbadaptor->get_ChromosomeAdaptor;
my $chr = $sb_chradp->fetch_by_chr_name($chr_name);

my $qy_species_dbadaptor = $gdbadp->fetch_by_species_tag($qy_species)->db_adaptor;

my $qy_chradp = $qy_species_dbadaptor->get_ChromosomeAdaptor;
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

unless (defined $dnafrag_type) {
  $dnafrag_type = "Chromosome";
}

if ($chr_start > $chr->length) {
  warn "chr_start $chr_start larger than chr_length ".$chr->length."
exit 3\n";
  exit 3;
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

my $sb_species_sliceadaptor = $sb_species_dbadaptor->get_SliceAdaptor;
my $qy_species_sliceadaptor = $qy_species_dbadaptor->get_SliceAdaptor;

my $gad = $db->get_GenomicAlignAdaptor;

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$gad->fetch_DnaDnaAlignFeature_by_species_chr_start_end($sb_species,$qy_species,$chr_name,$chr_start,$chr_end,$dnafrag_type)};

my $index = 0;

foreach my $ddaf (@DnaDnaAlignFeatures) {

  my $hstrand;
  $hstrand = "+" if ($ddaf->hstrand > 0);
  $hstrand = "-" if ($ddaf->hstrand < 0);

  if ($hstrand eq "-") {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$qy_chrs{$ddaf->hseqname}->length - $ddaf->hend + 1," ",$qy_chrs{$ddaf->hseqname}->length - $ddaf->hstart + 1," ",$hstrand," 0\n";
  } else {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$hstrand," 0\n";
  }
  my $sb_seq = $sb_species_sliceadaptor->fetch_by_chr_start_end($ddaf->seqname,$ddaf->start,$ddaf->end)->seq;
  my $qy_seq;
  if ($ddaf->hstrand > 0) {
    $qy_seq = $qy_species_sliceadaptor->fetch_by_chr_start_end($ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->seq;
  } else {
    $qy_seq = $qy_species_sliceadaptor->fetch_by_chr_start_end($ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->invert->seq;
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
