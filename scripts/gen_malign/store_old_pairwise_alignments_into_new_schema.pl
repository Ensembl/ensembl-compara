#!/usr/local/ensembl/bin/perl

my $description = q{
###############################################################################
##
##  PROGRAM store_old_pairwise_alignments_into_new_schema.pl
##
##  AUTHOR Javier Herrero (jherrero@ebi.ac.uk)
##
##    This software is part of the EnsEMBL project.
##
##  DESCRIPTION This program connects to an old database to fetch pairwise
##     alignments and store them into a new database.
##
##  DATE 28-June-2004
##
###############################################################################

};

=head1 NAME

store_old_pairwise_alignments_into_new_schema.pl

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This software is part of the EnsEMBL project.

=head1 DESCRIPTION

This program connects to an old database to fetch pariwise alignments and store them into a new database.

=head1 USAGE

store_old_pairwise_alignments_into_new_schema.pl [-help]
  -old_host mysql_host_server (for old ensembl_compara DB)
  -old_dbuser db_username
  -old_dbpass db_password
  -old_dbname ensembl_compara_database
  -old_port mysql_host_port
  -new_host mysql_host_server (for new ensembl_compara DB)
  -new_dbuser db_username
  -old_dbpass db_password
  -new_dbname ensembl_compara_database
  -new_port mysql_host_port

=head1 KNOWN BUGS

None at this moment.

=head1 INTERNAL FUNCTIONS

=cut

use strict;
use DBI;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlignGroup;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception qw( verbose );
use Getopt::Long;

###############################################################################
##  CONFIGURATION VARIABLES:
###############################################################################
###############################################################################

my $arguments = join(" ", @ARGV);
$arguments =~ s/ \-/\n   \-/g;
my $command_line = "$0\n   $arguments\n";

my $usage = qq{USAGE:
$0 [-help]
  -old_host mysql_host_server (for old ensembl_compara DB)
  -old_dbuser db_username
  -old_dbpass db_password
  -old_dbname ensembl_compara_database
  -old_port mysql_host_port
  -new_host mysql_host_server (for new ensembl_compara DB)
  -new_dbuser db_username
  -old_dbpass db_password
  -new_dbname ensembl_compara_database
  -new_port mysql_host_port
  -method_link_id method_link_id (optional, only stores entries with this method_link_id)
  -start first_row (default = 0)
  -num number_of_rows (default = last)
};

my $help = 0;
my $old_dbhost = "ecs2";
my $old_dbname = "abel_ensembl_compara_23_1";
my $old_dbuser = "ensro";
my $old_dbpass;
my $old_dbport = '3362';
my $new_dbhost = "ecs2";
my $new_dbname = "jh7_ensembl_compara_23_1_malign";
my $new_dbuser;
my $new_dbpass;
my $new_dbport = '3362';
my $method_link_id;
my $start;
my $num;
my $verbose = 0;

	
GetOptions('help' => \$help,
	   'old_host=s' => \$old_dbhost,
	   'old_dbname=s' => \$old_dbname,
	   'old_dbuser=s' => \$old_dbuser,
	   'old_dbpass=s' => \$old_dbpass,
	   'old_port=i' => \$old_dbport,
	   'new_host=s' => \$new_dbhost,
	   'new_dbname=s' => \$new_dbname,
	   'new_dbuser=s' => \$new_dbuser,
	   'new_dbpass=s' => \$new_dbpass,
	   'new_port=i' => \$new_dbport,
	   'method_link_id=s' => \$method_link_id,
	   'start=i' => \$start,
	   'num=i' => \$num,
	   'v' => \$verbose,
	   );

if ($help) {
  print $description, $usage;
  exit(0);
}

if ($verbose) {
  verbose('INFO');
}

if (!$old_dbhost or !$old_dbname or !$old_dbuser or !$old_dbport) {
  print "ERROR: Not enough information to connect to the old database!\n", $usage;
  exit(1);
}
if (!$new_dbhost or !$new_dbname or !$new_dbuser or !$new_dbport) {
  print "ERROR: Not enough information to connect to the new database!\n", $usage;
  exit(1);
}

my $old_dbh = DBI->connect("dbi:mysql:database=$old_dbname;host=$old_dbhost;port=$old_dbport", $old_dbuser, $old_dbpass);

my $new_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(
        -host   => $new_dbhost,
        -user   => $new_dbuser,
        -pass   => $new_dbpass,
        -port   => $new_dbport,
        -dbname => $new_dbname
    );

    
my $dnafrag_adaptor = $new_db->get_DnaFragAdaptor();
my $mlssa = $new_db->get_MethodLinkSpeciesSetAdaptor();
my $genomic_align_block_adaptor = $new_db->get_GenomicAlignBlockAdaptor();
my $genomic_align_group_adaptor = $new_db->get_GenomicAlignGroupAdaptor();

my $old_sql = qq{
          SELECT
                  consensus_dnafrag_id,
                  consensus_start,
                  consensus_end,
                  query_dnafrag_id,
                  query_start,
                  query_end,
                  query_strand,
                  method_link_id,
                  score,
                  perc_id,
                  cigar_line,
                  group_id,
                  level_id,
                  strands_reversed
          FROM genomic_align_block
          };
if (defined($method_link_id)) {
  $old_sql .= " WHERE method_link_id = $method_link_id";
}

if (defined($num)) {
  if (defined($start)) {
    $old_sql .= " LIMIT $start, $num";
  } else {
    $old_sql .= " LIMIT $num";
  }
}

my $old_sth = $old_dbh->prepare($old_sql);
$old_sth->execute();

my $method_link_species_sets;

my $consensus_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
my $query_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign();
my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock();
my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup ();

my $counter = 0;
while (my @values = $old_sth->fetchrow_array) {
  my $consensus_strand = ($values[13]==0)?1:-1;
  my $query_strand = ($values[13]==0)?$values[6]:-$values[6];
  my ($consensus_cigar_line, $query_cigar_line, $length) = parse_old_cigar_line($values[10]);
  
  my $consensus_dnafrag = $dnafrag_adaptor->fetch_by_dbID($values[0]);
  my $query_dnafrag = $dnafrag_adaptor->fetch_by_dbID($values[3]);
  
  my $genomes_key = join("+", sort ($consensus_dnafrag->genome_db->name,
          $query_dnafrag->genome_db->name));
  my $method_link_id = $values[7];
  my $method_link_species_set;
  if (!defined($method_link_species_sets->{$genomes_key}->{$method_link_id})) {
    $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet();
    $method_link_species_set->dbID(0);
    $method_link_species_set->method_link_id($method_link_id);
    $method_link_species_set->species_set([
            $consensus_dnafrag->genome_db,
            $query_dnafrag->genome_db
        ]);
    
    $method_link_species_set = $mlssa->store($method_link_species_set);
    $method_link_species_sets->{$genomes_key}->{$method_link_id} = $method_link_species_set;
  } else {
    $method_link_species_set = $method_link_species_sets->{$genomes_key}->{$method_link_id};
  }
#   print "MethodLinkSpeciesSet ($genomes_key) for ($method_link_id) = ", $method_link_species_set->dbID, "\n";
  
  $consensus_genomic_align->dbID(0);
  $consensus_genomic_align->method_link_species_set_id(0);
  $consensus_genomic_align->method_link_species_set($method_link_species_set);
  $consensus_genomic_align->dnafrag_id(0);
  $consensus_genomic_align->dnafrag($consensus_dnafrag);
  $consensus_genomic_align->dnafrag_start($values[1]);
  $consensus_genomic_align->dnafrag_end($values[2]);
  $consensus_genomic_align->dnafrag_strand($consensus_strand);
  $consensus_genomic_align->cigar_line($consensus_cigar_line);
  $consensus_genomic_align->level_id($values[12]);
  
#   $consensus_genomic_align->_print();
  
  $query_genomic_align->dbID(0);
  $query_genomic_align->method_link_species_set_id(0);
  $query_genomic_align->method_link_species_set($method_link_species_set);
  $query_genomic_align->dnafrag_id(0);
  $query_genomic_align->dnafrag($query_dnafrag);
  $query_genomic_align->dnafrag_start($values[4]);
  $query_genomic_align->dnafrag_end($values[5]);
  $query_genomic_align->dnafrag_strand($query_strand);
  $query_genomic_align->cigar_line($query_cigar_line);
  $query_genomic_align->level_id($values[12]);
  
#   $query_genomic_align->_print();
  
#   <STDIN>;

  $genomic_align_block->dbID(0);
  $genomic_align_block->method_link_species_set($method_link_species_set);
  $genomic_align_block->score($values[8]);
  $genomic_align_block->length($length);
  $genomic_align_block->perc_id($values[9]);
  $genomic_align_block->genomic_align_array([$consensus_genomic_align, $query_genomic_align]);
  
  $genomic_align_group->dbID($values[11]);
  $genomic_align_group->type("default");
  $genomic_align_group->genomic_align_array([$consensus_genomic_align, $query_genomic_align]);

  ## Store genomic_align_block (this stores genomic_aligns as well)
  $genomic_align_block_adaptor->store($genomic_align_block);

  ## Store genomic_align_group
  $genomic_align_group_adaptor->store($genomic_align_group);

  $counter++;
}

print $command_line;
print "$counter alignments stored.\n";

exit(0);

###############################################################################
##  PARSE OLD CIGAR LINE

=head2 parse_old_cigar_line

  Arg [1]    : string $old_cigar_line
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 

=cut

###############################################################################
sub parse_old_cigar_line {
  my ($old_cigar_line) = @_;
  my ($consensus_cigar_line, $query_cigar_line, $length);

  my @pieces = split(/(\d*[DIMG])/, $old_cigar_line);
  
#   print join("<- ->", @pieces);

  my $consensus_matches_counter = 0;
  my $query_matches_counter = 0;
  foreach my $piece ( @pieces ) {
    next if ($piece !~ /^(\d*)([MDI])$/);
    
    my $num = ($1 or 1);
    my $type = $2;

    if( $type eq "M" ) {
      $consensus_matches_counter += $num;
      $query_matches_counter += $num;
    
    } elsif( $type eq "D" ) {
      $consensus_cigar_line .= (($consensus_matches_counter == 1) ? "" : $consensus_matches_counter)."M";
      $consensus_matches_counter = 0;
      $consensus_cigar_line .= (($num == 1) ? "" : $num)."G";
      $query_matches_counter += $num;
    
    } elsif( $type eq "I" ) {
      $consensus_matches_counter += $num;
      $query_cigar_line .= (($query_matches_counter == 1) ? "" : $query_matches_counter)."M";
      $query_matches_counter = 0;
      $query_cigar_line .= (($num == 1) ? "" : $num)."G";
    }
    $length += $num;
  }
  $consensus_cigar_line .= (($consensus_matches_counter == 1) ? "" : $consensus_matches_counter)."M"
      if ($consensus_matches_counter);
  $query_cigar_line .= (($query_matches_counter == 1) ? "" : $query_matches_counter)."M"
      if ($query_matches_counter);

#   print join("\n", $old_cigar_line, $consensus_cigar_line, $query_cigar_line, $length);
  
  return ($consensus_cigar_line, $query_cigar_line, $length);
}
