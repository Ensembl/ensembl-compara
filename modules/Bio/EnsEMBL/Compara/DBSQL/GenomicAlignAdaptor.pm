# Copyright EnsEMBL 1999-2003
#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlignAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::DBSQL::GenomicAlignAdaptor

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor; 
  my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (
      -host => $host,
      -user => $dbuser,
      -pass => $dbpass,
      -port => $port,
      -dbname => $dbname,
      -conf_file => $conf_file);
  
  my $genomic_align_adaptor = $db->get_GenomicAlignAdaptor();

  $genomic_align_adaptor->store($genomic_align);

  my $genomic_align = $genomic_align_adaptor->fetch_by_dbID(1);
  my $genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block(23);
  my $genomic_aligns = $genomic_align_adaptor->fetch_all_by_genomic_align_block($genomic_align_block);


=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception qw(throw deprecate warning info);

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);

my $DEFAULT_MAX_ALIGNMENT = 20000;

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);

  my $vals =
    $self->db->get_MetaContainer->list_value_by_key('max_alignment_length');

  if(@$vals) {
    $self->{'max_alignment_length'} = $vals->[0];
  } else {
    $self->warn("Meta table key 'max_alignment_length' not defined\n" .
	       "using default value [$DEFAULT_MAX_ALIGNMENT]");
    $self->{'max_alignment_length'} = $DEFAULT_MAX_ALIGNMENT;
  }

  return $self;
}


=head2 store

  Arg  1     : listref  Bio::EnsEMBL::Compara::GenomicAlign $ga 
               The things you want to store
  Example    : none
  Description: It stores the give GA in the database. Attached
               objects are not stored. Make sure you store them first.
  Returntype : none
  Exceptions : not stored linked dnafrag objects throw.
  Caller     : $object->methodname

=cut

sub store {
  my ( $self, $genomic_aligns ) = @_;

  my $genomic_align_sql = qq{INSERT INTO genomic_align (
          genomic_align_id,
          genomic_align_block_id,
          method_link_species_set_id,
          dnafrag_id,
          dnafrag_start,
          dnafrag_end,
          dnafrag_strand,
          cigar_line,
          level_id
      ) VALUES (?,?,?, ?,?,?, ?,?,?)};
  
  my $genomic_align_sth = $self->prepare($genomic_align_sql);
  
  for my $ga ( @$genomic_aligns ) {
    if(!defined($ga->dnafrag) or !defined($ga->dnafrag->dbID)) {
      throw( "dna_fragment in GenomicAlign is not in DB" );
    }
    if(!defined($ga->genomic_align_block) or !defined($ga->genomic_align_block->dbID)) {
      throw( "genomic_align_block in GenomicAlign is not in DB" );
    }
    if(!defined($ga->method_link_species_set) or !defined($ga->method_link_species_set->dbID)) {
      throw( "method_link_species_set in GenomicAlign is not in DB" );
    }

    $genomic_align_sth->execute(
            ($ga->dbID or "NULL"),
            $ga->genomic_align_block->dbID,
            $ga->method_link_species_set->dbID,
            $ga->dnafrag->dbID,
            $ga->dnafrag_start,
            $ga->dnafrag_end,
            $ga->dnafrag_strand,
            ($ga->cigar_line or "NULL"),
            ($ga->level_id or 1)
        );

    if (!$ga->dbID) {
      $ga->dbID($genomic_align_sth->{'mysql_insertid'});
    }
    
    info("Stored Bio::EnsEMBL::Compara::GenomicAlign ".
          ($ga->dbID or "NULL").
          ", gab=".$ga->genomic_align_block->dbID.
          ", mlss=".$ga->method_link_species_set->dbID.
          ", dnaf=".$ga->dnafrag->dbID.
          " [".$ga->dnafrag_start.
          "-".$ga->dnafrag_end."]".
          " (".$ga->dnafrag_strand.")".
          ", cgr=".($ga->cigar_line or "NULL").
          ", lvl=".($ga->level_id or 1));

  }
}
     

=head2 delete_by_genomic_align_block_id

  Arg  1     : integer $genomic_align_block_id
  Example    : $gen_ali_blk_adaptor->delete_by_genomic_align_block_id(352158763);
  Description: It removes the mathing GenomicAlign objects from the database
  Returntype : none
  Exceptions : 
  Caller     : general

=cut

sub delete_by_genomic_align_block_id {
  my ($self, $genomic_align_block_id) = @_;

  my $genomic_align_sql =
        qq{DELETE FROM genomic_align WHERE genomic_align_block_id = ?};
  
  ## Deletes genomic_block entries
  my $sth = $self->prepare($genomic_align_sql);
  $sth->execute($genomic_align_block_id);
}


=head2 fetch_by_dbID

  Arg  1     : integer $dbID
  Example    : my $genomic_align = $genomic_align_adaptor->fetch_by_dbID(23134);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlign object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : Returns undef if no matching entry is found in the database.
  Caller     : object::methodname

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $genomic_align;

  my $sql = qq{
          SELECT
              genomic_align_id,
              genomic_align_block_id,
              method_link_species_set_id,
              dnafrag_id,
              dnafrag_start,
              dnafrag_end,
              dnafrag_strand,
              cigar_line,
              level_id
          FROM
              genomic_align
          WHERE
              genomic_align_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  my @values = $sth->fetchrow_array();
  $genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
          -dbID => $values[0],
          -adaptor => $self,
          -genomic_align_block_id => $values[1],
          -method_link_species_set_id => $values[2],
          -dnafrag_id => $values[3],
          -dnafrag_start => $values[4],
          -dnafrag_end => $values[5],
          -dnafrag_strand => $values[6],
          -cigar_line => $values[7],
          -level_id => $values[8],
      );

  return $genomic_align;
}


=head2 fetch_all_by_genomic_align_block

  Arg  1     : integer $genomic_align_block_id
                  - or -
               Bio::EnsEMBL::Compara::GenomicAlignBlock object with a valid dbID
  Example    : my $genomic_aligns =
                    $genomic_align_adaptor->fetch_all_by_genomic_align_block(23134);
  Example    : my $genomic_aligns =
                    $genomic_align_adaptor->fetch_all_by_genomic_align_block($genomic_align_block);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlign objects
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : Returns a ref. to an empty array if there are no matching entries
  Exceptions : Thrown if $genomic_align_block is neither a number or a
               Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Caller     : object::methodname

=cut

sub fetch_all_by_genomic_align_block {
  my ($self, $genomic_align_block) = @_;
  my $genomic_aligns = [];

  if ($genomic_align_block !~ /^\d+$/) {
    throw("$genomic_align_block is not a Bio::EnsEMBL::Compara::GenomicAlignBlock object")
        if (!$genomic_align_block->isa("Bio::EnsEMBL::Compara::GenomicAlignBlock"));
    $genomic_align_block = $genomic_align_block->dbID;
  }
  my $sql = qq{
          SELECT
              genomic_align_id,
              genomic_align_block_id,
              method_link_species_set_id,
              dnafrag_id,
              dnafrag_start,
              dnafrag_end,
              dnafrag_strand,
              cigar_line,
              level_id
          FROM
              genomic_align
          WHERE
              genomic_align_block_id = ?
      };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align_block);
  while (my @values = $sth->fetchrow_array()) {
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => $values[0],
            -adaptor => $self,
            -genomic_align_block_id => $values[1],
            -method_link_species_set_id => $values[2],
            -dnafrag_id => $values[3],
            -dnafrag_start => $values[4],
            -dnafrag_end => $values[5],
            -dnafrag_strand => $values[6],
            -cigar_line => $values[7],
            -level_id => $values[8],
        );
    push(@$genomic_aligns, $this_genomic_align);
  }

  return $genomic_aligns;
}


=head2 fetch_all_by_DnaFrag_GenomeDB (UNDER DEVELOPMENT)

  Arg  1     : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  2     : string $query_species
               The species where the caller wants alignments to
               his dnafrag.
  Arg [3]    : int $start
  Arg [4]    : int $end
  Arg [5]    : string $alignment_type
               The type of alignments to be retrieved
               i.e. WGA or WGA_HCR
  Example    :  ( optional )
  Description: testable description
  Returntype : listref of Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : object::methodname or just methodname

=cut

sub fetch_all_by_DnaFrag_GenomeDB {
  my ( $self, $dnafrag, $target_genome, $start, $end, $alignment_type, $limit) = @_;
  my $all_genomic_aligns = [];

  deprecate("Use Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor for fetching genomic alignments!");

  unless($dnafrag && ref $dnafrag && 
        $dnafrag->isa('Bio::EnsEMBL::Compara::DnaFrag')) {
    throw("dnafrag argument must be a Bio::EnsEMBL::Compara::DnaFrag" .
          " not a [$dnafrag]");
  }

  $limit = 0 unless (defined $limit);
  
  my $mlssa = $self->db->get_MethodLinkSpeciesSetAdaptor;
  my $gdba = $self->db->get_GenomeDBAdaptor;

  my $sql = qq{
          SELECT
            genomic_align_id,
            genomic_align_block_id,
            dnafrag_start,
            dnafrag_end,
            dnafrag_strand,
            cigar_line,
            level_id
          FROM
            genomic_align
          WHERE
            dnafrag_id = }.$dnafrag->dbID;

  my $method_link_species_set;
  if (defined($target_genome)) {
    $method_link_species_set = $mlssa->fetch_by_method_link_and_genome_db_ids(
            $alignment_type, [$dnafrag->genomedb->dbID, $target_genome->dbID]);
    return [] if (!$method_link_species_set);
    $sql .= " AND method_link_species_set_id = ". $method_link_species_set->dbID;
  }

  if (defined $start && defined $end) {
    my $lower_bound = $start - $self->{'max_alignment_length'};
    $sql .= ( " AND dnafrag_start <= $end
              AND dnafrag_start >= $lower_bound
              AND dnafrag_end >= $start" );
  }
  if ($limit > 0) {
    $sql .= " order by dnafrag_start asc limit $limit";
  } elsif ($limit < 0) {
    $sql .= " order by dnafrag_end desc limit " . abs($limit);
  }

  my $sth = $self->prepare($sql);
# print STDERR $sql,"\n";
  $sth->execute();

  while (my ($gaid, $gabid, $dfst, $dfed, $dfsd, $cgln, $lvid) = $sth->fetchrow_array) {
    print join(" ", $gaid, $gabid, $dfst, $dfed, $dfsd, $cgln, $lvid), "\n";
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dbID => $gaid,
            -adaptor => $self,
            -genomic_align_block_id => $gabid,
            -method_link_species_set_id => $method_link_species_set->dbID,
            -method_link_species_set => $method_link_species_set,
            -dnafrag => $dnafrag,
            -dnafrag_start => $dfst,
            -dnafrag_end => $dfed,
            -dnafrag_strand => $dfsd,
            -cigar_line => $cgln,
            -level_id => $lvid,
        );
    push(@{$all_genomic_aligns}, $this_genomic_align);
  }

  return $all_genomic_aligns;
}


=head2 store_daf (UNDER DEVELOPMENT)

  Arg  1     : 
  Example    : 
  Description: 
  Returntype : 
  Exceptions : 
  Caller     : 

=cut

sub store_daf {
  my ($self, $dafs, $dnafrag, $hdnafrag, $alignment_type) = @_;
  my @gas;
  foreach my $daf (@{$dafs}) {
    my $ga = Bio::EnsEMBL::Compara::GenomicAlign->new_fast
      ('consensus_dnafrag' => $dnafrag,
        'consensus_start' => $daf->start,
        'consensus_end' => $daf->end,
        'query_dnafrag' => $hdnafrag,
        'query_start' => $daf->hstart,
        'query_end' => $daf->hend,
        'query_strand' => $daf->hstrand,
        'alignment_type' => $alignment_type,
        'score' => $daf->score,
        'perc_id' => $daf->percent_id,
        'group_id' => $daf->group_id,
        'level_id' => $daf->level_id,
        'cigar_line' => $daf->cigar_string
       );
          push @gas, $ga;
  }
  $self->store(\@gas);
}


=head2 retrieve_all_direct_attributes

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlign $genomic_align
  Example    : $genomic_align_adaptor->retrieve_all_direct_attributes($genomic_align)
  Description: Retrieve the all the direct attibutes corresponding to the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlign object. It is used after lazy fetching
               of the object for populating it when required.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlign object
  Exceptions : 
  Caller     : none

=cut

sub retrieve_all_direct_attributes {
  my ($self, $genomic_align) = @_;

  my $sql = qq{
                SELECT
                    genomic_align_block_id,
                    method_link_species_set_id,
                    dnafrag_id,
                    dnafrag_start,
                    dnafrag_end,
                    dnafrag_strand,
                    cigar_line,
                    level_id
                FROM
                    genomic_align
                WHERE
                    genomic_align_id = ?
        };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align->dbID);
  my ($genomic_align_block_id, $method_link_species_set_id, $dnafrag_id, $dnafrag_start, $dnafrag_end,
          $dnfrag_strand, $cigar_line, $level_id) = $sth->fetchrow_array();
  
  ## Populate the object
  $genomic_align->adaptor($self);
  $genomic_align->genomic_align_block_id($genomic_align_block_id) if (defined($genomic_align_block_id));
  $genomic_align->method_link_species_set_id($method_link_species_set_id) if (defined($method_link_species_set_id));
  $genomic_align->dnafrag_id($dnafrag_id) if (defined($dnafrag_id));
  $genomic_align->dnafrag_start($dnafrag_start) if (defined($dnafrag_start));
  $genomic_align->dnafrag_end($dnafrag_end) if (defined($dnafrag_end));
  $genomic_align->dnafrag_strand($dnfrag_strand) if (defined($dnfrag_strand));
  $genomic_align->cigar_line($cigar_line) if (defined($cigar_line));
  $genomic_align->level_id($level_id) if (defined($level_id));

  return $genomic_align;
}


1;
