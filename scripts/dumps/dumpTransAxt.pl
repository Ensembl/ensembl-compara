#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::DnaDnaAlignFeature;
use Bio::EnsEMBL::Exon;
use Bio::EnsEMBL::Translation;
use Bio::EnsEMBL::Transcript;
use Bio::Tools::CodonTable;
use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -dbname ensembl_compara_database
   -port eg 3352 (default)
   -seq_region (eg chromosome:22) was chr_name e.g. 22
   -seq_region_start was chr_start
   -seq_region_end was chr_end
   -species1 (e.g. \"Homo sapiens\") from which alignments are queried and chr_name refer to
   -assembly1 (e.g. NCBI30) assembly version of species1
   -species2 (e.g. \"Mus musculus\") to which alignments are queried
   -assembly2 (e.g. MGSC3) assembly version of species2
   -alignment_type type of alignment stored e.g. BLASTZ_NET (default: BLASTZ_NET) 
   -align DNA, AA or BOTH (ie how the alignment should be printed, as DNA, aminoacid or both (default=AA)
   -limit
   -conf_file compara_conf_file
              see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
";

my ($host,$dbname);
my $dbuser = 'ensro';
#my ($chr_name,$chr_start,$chr_end);
my ($seq_region,$seq_region_start,$seq_region_end);
my ($species1,$assembly1,$species2,$assembly2);
my $conf_file;
my $help = 0;
my $alignment_type = "BLASTZ_NET";
my $align = "AA";
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
	   'align=s'	=>  \$align,
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

unless ($seq_region =~ /^\S+:\S+$/) {
  warn "
seq_region should have be coordinate_system_name:seq_region_name,
e.g. chromosome:22 or scaffold:scaffold_10
EXIT 1\n";
  exit 1;
}
my ($coordinate_system_name, $seq_region_name) = split ":", $seq_region;
my $sliceadaptor = $db->get_db_adaptor($species1,$assembly1)->get_SliceAdaptor;
my $slice = $sliceadaptor->fetch_by_region($coordinate_system_name,$seq_region_name);

# further checks on arguments

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

print "\n\tPlease note alignment varies from Axt format in that both target and query\n\tstrand (in order) are given (eg. -+) in place of just the query strand\n\n";
my $dafad = $db->get_DnaAlignFeatureAdaptor;

my @DnaDnaAlignFeatures = sort {$a->start <=> $b->start || $a->end <=> $b->end} @{$dafad->fetch_all_by_species_region($species1,"$assembly1",$species2,"$assembly2",$seq_region_name,$seq_region_start,$seq_region_end,$alignment_type,$limit,$coordinate_system_name)};

#print STDERR "$species1,$assembly1,$species2,$assembly2,$seq_region_name,$seq_region_start,$seq_region_end,$alignment_type,$limit,$coordinate_system_name\n";

my $index = 0;

foreach my $ddaf (@DnaDnaAlignFeatures) {
   # print STDERR $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->score," \n";
    
  if ($ddaf->cigar_string eq "") {
    warn $ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$ddaf->hstrand," ",$ddaf->score," has no cigar line";
    next;
  }

  my $hstrand; my $strand;
  my $flip=0;
  if ($ddaf->strands_reversed == 1){
  	$ddaf->reverse_complement();
	$flip=1;
	}
  
  
  $hstrand = "+" if ($ddaf->hstrand > 0);
  $hstrand = "-" if ($ddaf->hstrand < 0);
  $strand = "+" if ($ddaf->strand > 0);
  $strand = "-" if ($ddaf->strand < 0);

  if (($hstrand eq "-") &&($strand eq "+")) {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hslice->length - $ddaf->hend + 1," ",$ddaf->hslice->length - $ddaf->hstart + 1," ",$strand.$hstrand," ",$ddaf->score,"\n";
  } 
  elsif (($strand eq "-") && ($hstrand eq "+")){
    print $index," ",$ddaf->seqname," ",$ddaf->slice->length - $ddaf->end + 1," ",$ddaf->slice->length - $ddaf->start + 1," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$strand.$hstrand," ",$ddaf->score,"\n";  
  	}
  elsif (($strand eq "-") && ($hstrand eq "-")){
    print $index," ",$ddaf->seqname," ",$ddaf->slice->length - $ddaf->end + 1," ",$ddaf->slice->length - $ddaf->start + 1," ",$ddaf->hseqname," ",$ddaf->hslice->length - $ddaf->hend + 1," ",$ddaf->hslice->length - $ddaf->hstart + 1," ",$strand.$hstrand," ",$ddaf->score,"\n";  
  	}
  else {
    print $index," ",$ddaf->seqname," ",$ddaf->start," ",$ddaf->end," ",$ddaf->hseqname," ",$ddaf->hstart," ",$ddaf->hend," ",$strand.$hstrand," ",$ddaf->score,"\n";
  }
  my $sb_seq ;
  my $qy_seq;

#= $ddaf->slice->adaptor->fetch_by_region($ddaf->slice->coord_system->name,$ddaf->seqname,$ddaf->start,$ddaf->end)->seq;

  if ($ddaf->strand > 0) {
    $sb_seq = $ddaf->slice->adaptor->fetch_by_region($ddaf->slice->coord_system->name,$ddaf->seqname,$ddaf->start,$ddaf->end)->seq;
  } else {
    $sb_seq = $ddaf->slice->adaptor->fetch_by_region($ddaf->slice->coord_system->name,$ddaf->seqname,$ddaf->start,$ddaf->end)->invert->seq;
  }


  if ($ddaf->hstrand > 0) {
    $qy_seq = $ddaf->hslice->adaptor->fetch_by_region($ddaf->hslice->coord_system->name,$ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->seq;
  } else {
    $qy_seq = $ddaf->hslice->adaptor->fetch_by_region($ddaf->hslice->coord_system->name,$ddaf->hseqname,$ddaf->hstart,$ddaf->hend)->invert->seq;
  }
  ($sb_seq,$qy_seq) = make_gapped_align_from_cigar_string($sb_seq,$qy_seq,$ddaf->cigar_string);
  
  unless ($align eq 'AA'){
 	 print lc $sb_seq,"\n";
  	print lc $qy_seq,"\n";
	}

  my $sb_peptide= Bio::Seq->new( -seq => $sb_seq,
  				 -moltype => "dna",
				 -alphabet => 'dna',
				 -id =>$ddaf->seqname);
  my $qy_peptide= Bio::Seq->new( -seq => $qy_seq,
  				 -moltype => "dna",
				 -alphabet => 'dna',
				 -id =>$ddaf->hseqname);
unless ($align eq'DNA'){
	print $sb_peptide->translate->seq."\n";
	print $qy_peptide->translate->seq."\n";
	}
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
