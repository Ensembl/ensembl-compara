#!/usr/local/ensembl/bin/perl

my $description = q{
###############################################################################
##
##  PROGRAM store_multiz_alignment.pl
##
##  AUTHOR Javier Herrero (jherrero@ebi.ac.uk)
##
##    This software is part of the EnsEMBL project.
##
##  DESCRIPTION: This program reads a multiz file and stores all the
##    alignments into the selected database.
##
###############################################################################

};

=head1 NAME

store_multiz_alignment.pl

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This software is part of the EnsEMBL project.

=head1 DESCRIPTION

This program reads a multiz file and stores all the alignments into the
selected database.

=head1 USAGE

store_multiz_alignment.pl [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'ensro')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3352)
  -conf_file compara_conf_file
      see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
  -multiz_file file_containing_multiz_alignemnts
  -verbose V (from 0 to 3, default is 0)
  -skip (ignores unknown genome assemblies and skips the whole alignment)
  -force (ignores unknown genome assemblies but stores the remaining sequences of the aligment)

=head1 KNOWN BUGS

(*) DnaFrag entries must exist in the database. Fake DnaFrag used as a consensus
DnaFrag for multiple alignments must exist as well.

(*) Information needed to map UCSC species names into EnsEMBL naming system is
hard-coded and thus will get out-to-date at some stage.

(*) This program does not check for duplicates.

(*) With -skip option on, this program simply ignores the whole alignment when if finds an entries corresponding to unknown genome assemblies.

(*) With -force option on, this program simply ignores entries corresponding to unknown genome assemblies.

(*) This script has not been fully tested yet...

=head1 INTERNAL FUNCTIONS

=cut

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Getopt::Long;

###############################################################################
##  CONFIGURATION VARIABLES:
##   (*) $ucsc_2_ensembl:  maps the UCSC species names into the EnseEMBL
##           species naming system.
###############################################################################
my $ucsc_2_ensembl = {
	"hg16" => {'name' => "Homo sapiens", 'assembly' => "NCBI34"},
	"rn3"  => {'name' => "Rattus norvegicus", 'assembly' => "RGSC3.1"},
	"galGal2" => {'name' => "Gallus gallus", 'assembly' => "WASHUC1"},
	};
###############################################################################

my $usage = qq{USAGE:
$0 [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'ensro')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3352)
  -conf_file compara_conf_file
      see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example
  -multiz_file file_containing_multiz_alignemnts
  -verbose V (from 0 to 3, default is 0)
};

my $help = 0;
my $verbose = 0;
my $skip = 0;
my $force = 0;
my $dbhost;
my $dbname;
my $dbuser;
my $dbpass;
my $dbport = '3352';
my $conf_file;
my $multiz_file;

	
GetOptions('help' => \$help,
	   'host=s' => \$dbhost,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'port=i' => \$dbport,
	   'conf_file=s' => \$conf_file,
	   'verbose=i' => \$verbose,
	   'skip' => \$skip,
	   'force' => \$force,
	   'multiz_file=s' => \$multiz_file,
	   );

if ($help) {
  print $description, $usage;
  exit(0);
}

if (!$dbhost or !$dbname or !$dbuser or !$dbport or !$conf_file) {
  print "ERROR: Not enough information to connect to the database!\n", $usage;
  exit(1);
}

if (!$multiz_file or !open(MULTIZ, $multiz_file)) {
  print "ERROR: Cannot open <$multiz_file> file!\n", $usage;
  exit(1);
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $dbhost,
						     -user   => $dbuser,
						     -pass   => $dbpass,
						     -port   => $dbport,
						     -dbname => $dbname,
						     -conf_file => $conf_file);
						     
my $genome_db_adaptor = $db->get_GenomeDBAdaptor();
my $dnafrag_adaptor = $db->get_DnaFragAdaptor();
my $genomic_align_adaptor = $db->get_GenomicAlignAdaptor();
my $slice_adaptor;

my $fake_genome_db = $genome_db_adaptor->fetch_by_name_assembly('fake', 'null');
my $fake_dnafrag = get_this_dnafrag($fake_genome_db, 'chromosome', 'universal');
die "DnaFrag for fake consensus dna is not in the database" if (!$fake_dnafrag);

my $print_multiple_alignment = ""; #used for verbose output
my $sequences = "";
my $score = 0;
my @multiple_alignment; #array of Bio::EnsEMBL::Compara::GenomicAlign objects to store as a single multiple alignment
my $store_this_malign = 1;

while (<MULTIZ>) {
  ## For all lines that are not "s" lines (parts of the multiple alignment)
  if (!/^s\s+([^\.]+)\.chr(\S+)\s+(\d+)\s+(\d+)\s+([\+\-])\s+\d+\s+(.+)$/) {
    
    ## Stores multiple alignment
    if (@multiple_alignment) {
      if ($store_this_malign) {
        $genomic_align_adaptor->store_malign(\@multiple_alignment);
      } else {
        print "SKIPPING:\n", $print_multiple_alignment;
      }
      $store_this_malign = 1;
      undef(@multiple_alignment);
    }
    
    ## Retrieves score of the multpile alignment
    if (/^a/ && /score=(\d+(\.\d+)?)/) {
      print $print_multiple_alignment, "\n", $sequences, "\n\n" if (($verbose > 1) && $print_multiple_alignment);
      $print_multiple_alignment = "";
      $sequences = "";
      $score = $1;
    }
    
    next;
  }

  ## Next is for "s" lines only  
  $print_multiple_alignment .= $_;
  
  print "$1 - $2 - $3 - $4 - ($5) - $6\n" if ($verbose > 2);
  my $species = $1;
  my $chromosome = $2;
  my $start_pos = $3;
  my $length = $4;
  my $strand = ($5 eq '+')?1:-1;
  my $alignment = $6;
  
  ## Deal with unknown assemblies
  if (!defined($ucsc_2_ensembl->{$species})) {
    if ($force) {
      print "IGNORING: $species.chr$chromosome\n";
      next;
    } elsif ($skip) {
      $store_this_malign = 0;
      next;
    } else {
      die "Cannot map UCSC species name: $species\n";
    }
  }
  
  ## Deal with unknown chromosomes
  if ($chromosome =~ /random/) {
    if ($force) {
      print "IGNORING: $species.chr$chromosome\n";
      next;
    } elsif ($skip) {
      $store_this_malign = 0;
      next;
    } else {
      die "Cannot use: $species.chr$chromosome\n";
    }
  }
  my $species_name = $ucsc_2_ensembl->{$species}->{'name'};
  my $species_assembly = $ucsc_2_ensembl->{$species}->{'assembly'};
  
  my $cigar_line = get_cigar_line_from_gapped_sequence($alignment);
  
  if (!defined($slice_adaptor->{$species})) {
    $slice_adaptor->{$species} = $db->get_db_adaptor($species_name, $species_assembly)->get_SliceAdaptor;
  }
  
  die "Cannot connect to ", $ucsc_2_ensembl->{$species}->{'name'}, "\n" if (!defined($slice_adaptor->{$species}));

  my $slice = get_this_slice($species, $chromosome, $start_pos, $length, $strand);
  my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($species_name, $species_assembly);
  my $dnafrag = get_this_dnafrag($genome_db, 'chromosome', $chromosome);
  die "Cannot fetch DnaFrag for ".$ucsc_2_ensembl->{$species}->{'name'}.", chromosome $chromosome\n" if (!$dnafrag);
  
  my $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
		-consensus_dnafrag => $fake_dnafrag,
		-consensus_start => 1,
		-consensus_end => length($alignment),
		-query_dnafrag => $dnafrag,
		-query_start => $slice->start,
		-query_end => $slice->end,
		-query_strand => $slice->strand,
#		-alignment_type => ,
		-score => $score,
		-alignment_type => 'MULTIZ',
#		-perc_id => ,
		-cigar_line => $cigar_line,
  	);
  $genomic_align->group_id(0);
  $genomic_align->level_id(1);
  
#  print "                                       ", $genomic_align->alignment_strings("NO_SEQ")->[1], "\n";
  
  push(@multiple_alignment, $genomic_align);
}

if (@multiple_alignment) {
  if ($store_this_malign) {
    $genomic_align_adaptor->store_malign(\@multiple_alignment);
  } else {
    print "SKIPPING:\n", $print_multiple_alignment;
  }
}
print $print_multiple_alignment, "\n", $sequences, "\n\n" if ($verbose > 1);
 
exit(0);

###############################################################################
##  GET THIS SLICE

=head2 get_this_slice

  Arg [1]    : string $species
  Arg [2]    : string $chromosome
  Arg [2]    : string $start_pos
  Arg [2]    : string $length
  Arg [2]    : string $strand
  Example    : 
  Description: Takes UCSC coordinates and returns the corresponding slice
  Returntype : Bio::EnsEMBL::Slice
  Exceptions : 

=cut

###############################################################################
sub get_this_slice {
  my ($species, $chromosome, $start_pos, $length, $strand) = @_;
  my $slice;
    
  if ($strand == 1) {
    print "Fetching sequence ", ($start_pos+1), "-->", ($start_pos+$length), " from chromosome $chromosome of ",
	$ucsc_2_ensembl->{$species}->{'name'}, " (assembly ", $ucsc_2_ensembl->{$species}->{'assembly'}, ")\n"
	if ($verbose > 1);
    $slice = $slice_adaptor->{$species}->fetch_by_region('chromosome',
							 $chromosome,
							 ($start_pos+1),
							 ($start_pos+$length),
							 1);
  } elsif ($strand == -1) {
    print "Fetching sequence ", (-$start_pos-$length), "<--", ($start_pos), " from chromosome $chromosome of ",
	$ucsc_2_ensembl->{$species}->{'name'}, " (assembly ", $ucsc_2_ensembl->{$species}->{'assembly'}, ")\n"
	if ($verbose > 1);
    $slice = $slice_adaptor->{$species}->fetch_by_region('chromosome',
							 $chromosome);
    $slice = $slice_adaptor->{$species}->fetch_by_region('chromosome',
							 $chromosome,
							 ($slice->end()-$start_pos-$length+1),
							 ($slice->end()-$start_pos),
							 -1);
  }
  if ($slice && ($verbose > 1)) {
    my $sequence = $slice->start()." -> ".$slice->end()." (".($slice->strand()==1?"+":"-").") ";
    $sequences .= $sequence;
    for (my $a=0; $a<30-length($sequence); $a++) {$sequences .= " ";}
    $sequences .= $slice->seq()."\n";
  }

  return $slice;  
}


###############################################################################
##  GET_CIGAR_LINE_FROM_GAPPED_SEQUENCE

=head2 get_cigar_line_from_gapped_sequence

  Arg [1]    : string $sequence
  Example    : get_cigar_line_from_gapped_sequence("AGTA----GTGTC-TACTA--G");
               => "4M4G4MG5M2GM"
  Description: Translates a gapped sequence into a cigar line
               **WARNING** Returned sequence contains G for gaps!!
  Returntype : string
  Exceptions : dies if it founds any strange character in the sequence

=cut

###############################################################################
sub get_cigar_line_from_gapped_sequence {
  my ($sequence) = @_;
  my $cigar_line = "";

  # Check sequence
  $sequence =~ s/[\r\n]+$//;
  die "Unreadable sequence ($sequence)" if ($sequence !~ /^[\-A-Z]+$/i);
    
  my @pieces = split(/(\-+)/, $sequence);
  foreach my $piece (@pieces) {
    my $mode;
    if ($piece =~ /\-/) {
      $mode = "G"; #deletions are gaps in the consensus sequences. Those gaps are located in the query one.
    } else {
      $mode = "M";
    }
    if (length($piece) == 1) {
      $cigar_line .= $mode;
    } elsif (length($piece) > 1) { #length can be 0 if the sequence starts with a gap
      $cigar_line .= length($piece).$mode;
    }
  }

  return $cigar_line;
}


###############################################################################
##  GET THIS DNAFRAG

=head2 get_this_dnafrag

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
               The GenomeDB object corresponding to this dnafrag.
  Arg[2]     : string $fragment_type
  Arg[3]     : string $fragment_name
  Example    : get_this_danfrag($human_db, 'chromosome', '17');
  Description: Returns the corresponding DnaFrag object.
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : returns undef when the DnaFrag does not exist in the database.

=cut

###############################################################################
sub get_this_dnafrag {
  my ($genome_db, $fragment_type, $fragment_name) = @_;

  my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db, $fragment_type, $fragment_name);
  my $dnafrag;
  foreach my $this_dnafrag (@$dnafrags) {
    if ($this_dnafrag->type eq $fragment_type && $this_dnafrag->name eq $fragment_name) {
      $dnafrag = $this_dnafrag;
      last;
    }
  }
  
  #returns null if the dnafrag does not exist in the database
  return $dnafrag;
}

