# Copyright EnsEMBL 2004
#
# Ensembl module for Bio::EnsEMBL::DBSQL::GenomicAlignBlockAdaptor
# 
# POD documentation - main docs before the code
# 

=head1 NAME

Bio::EnsEMBL::DBSQL::Compara::GenomicAlignBlockAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::GenomicAlignBlockAdaptor;
use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Utils::Exception qw(throw);


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

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock
               The things you want to store
  Example    : $gen_ali_blk_adaptor->store($genomic_align_block);
  Description: It stores the given GenomicAlginBlock in the database as well
               as the GenomicAlign objects it contains
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : - method_link_species_set not stored in the DB
               - no Bio::EnsEMBL::Compara::GenomicAlign object is linked
               - not stored linked dnafrag objects throw.
               - unknown method link
               - cannot lock tables
               - cannot store GenomicAlignBlock object
               - cannot store corresponding GenomicAlign objects
  Caller     : general

=cut

sub store {
  my ($self, $genomic_align_block) = @_;

  my $genomic_align_block_sql =
        qq{INSERT INTO genomic_align_block (
                genomic_align_block_id,
                method_link_species_set,
                score,
                perc_id,
                length
        ) VALUES (?,?,?,?,?)};
  
  my @values;
  
  ## CHECKING
  if (!defined($genomic_align_block->method_link_species_set->dbID)) {
    throw("method_link_species_set in GenomicAlignBlock is not in DB");
  }
  throw if (!$genomic_align_block->genomic_align_array);
  foreach my $genomic_align (@{$genomic_align_block->genomic_align_array}) {
    # check if every GenomicAlgin has a dbID
    if (!defined($genomic_align->dnafrag->dbID)) {
      throw("dna_fragment in GenomicAlignBlock is not in DB");
    }
  }
  
  ## Stores data, all of them with the same id
  my $sth = $self->prepare($genomic_align_block_sql);
  #print $align_block_id, "\n";
  $sth->execute(
                ($genomic_align_block->dbID or "NULL"),
                $genomic_align_block->method_link_species_set->dbID,
                $genomic_align_block->score,
                $genomic_align_block->perc_id,
                $genomic_align_block->length
        );
  if (!$genomic_align_block->dbID) {
    $genomic_align_block->dbID($sth->{'mysql_insertid'});
  }
  
  ## Stores genomic_align entries
  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  $genomic_align_adaptor->store($genomic_align_block->genomic_align_array);

  return $genomic_align_block;
}


=head2 delete_by_dbID

  Arg  1     : integer $genomic_align_block_id
  Example    : $gen_ali_blk_adaptor->delete_by_dbID(352158763);
  Description: It removes the given GenomicAlginBlock in the database as well
               as the GenomicAlign objects it contains
  Returntype : none
  Exceptions : 
  Caller     : general

=cut

sub delete_by_dbID {
  my ($self, $genomic_align_block_id) = @_;

  my $genomic_align_block_sql =
        qq{DELETE FROM genomic_align_block WHERE genomic_align_block_id = ?};
  
  ## Deletes genomic_align_block entry 
  my $sth = $self->prepare($genomic_align_block_sql);
  $sth->execute($genomic_align_block_id);
  
  ## Deletes corresponding genomic_align entries
  my $genomic_align_adaptor = $self->db->get_GenomicAlignAdaptor;
  $genomic_align_adaptor->delete_by_genomic_align_block_id($genomic_align_block_id);
}


=head2 fetch_by_dbID

  Arg  1     : integer $genomic_align_block_id
  Example    : my $genomic_align_block = $genomic_align_block_adaptor->fetch_by_dbID(1)
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : Returns undef if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $genomic_align_block; # returned object

  my $sql = qq{
                SELECT
                    method_link_species_set, score, perc_id, length
                FROM
                    genomic_align_block
                WHERE
                    genomic_align_block_id = ?
        };

  my $sth = $self->prepare($sql);
  $sth->execute($dbID);
  my $array_ref = $sth->fetchrow_arrayref();
  if ($array_ref) {
    my ($method_link_species_set_id, $score, $perc_id, $length) = @$array_ref;
  
    ## Create the object
    # Lazy loading of genomic_align objects. They are fetched only when needed.
    $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                          -adaptor => $self,
                          -dbID => $dbID,
                          -method_link_species_set_id => $method_link_species_set_id,
                          -score => $score,
                          -perc_id => $perc_id,
                          -length => $length
                  );
  }

  return $genomic_align_block;
}


=head2 fetch_all_by_dnafrag_and_method_link_species_set

  Arg  1     : integer $dnafrag_id
                    - or -
               Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Arg  2     : integer $start
  Arg  3     : integer $end
  Arg  4     : integer $method_link_species_set_id
                    - or -
               Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_set
  Example    : my $genomic_align_blocks =
                  $genomic_align_block_adaptor->fetch_all_by_dnafrag_and_method_link_species_set(
                      19, 50000000, 50250000, 2);
  Description: Retrieve the corresponding
               Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Objects 
  Returntype : ref. to an array of Bio::EnsEMBL::Compara::GenomicAlignBlock objects. Only dbID,
               adaptor and method_link_species_set are actually stored in the objects. The remaining
               attributes are only retrieved when requiered.
  Exceptions : Returns ref. to an empty array if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

=cut

sub fetch_all_by_dnafrag_and_method_link_species_set {
  my ($self, $dnafrag, $start, $end, $method_link_species_set) = @_;
  my $genomic_align_blocks = []; # returned object

  my $dnafrag_id;
  if ($dnafrag =~ /^\d+$/) {
    $dnafrag_id = $dnafrag;
  } else {
    throw("$dnafrag is not a Bio::EnsEMBL::Compara::DnaFrag object")
        if (!$dnafrag->isa("Bio::EnsEMBL::Compara::DnaFrag"));
    $dnafrag_id = $dnafrag->dbID;
  }

  my $method_link_species_set_id;
  if ($method_link_species_set =~ /^\d+$/) {
    $method_link_species_set_id = $method_link_species_set;
  } else {
    throw("$method_link_species_set is not a Bio::EnsEMBL::Compara::MethodLinkSpeciesSet object")
        if (!$method_link_species_set->isa("Bio::EnsEMBL::Compara::MethodLinkSpeciesSet"));
    $method_link_species_set_id = $method_link_species_set->dbID;
  }

  my $lower_bound = $start - $self->{'max_alignment_length'};
  my $sql = qq{
                SELECT
                    genomic_align_block_id
                FROM
                    genomic_align
                WHERE 
                    method_link_species_set = $method_link_species_set_id AND
                    dnafrag_id = $dnafrag_id AND
                    dnafrag_start <= $end AND
                    dnafrag_start >= $lower_bound AND
                    dnafrag_end >= $start
        };
  my $sth = $self->prepare($sql);
  $sth->execute();

  my $all_genomic_align_block_ids;
  while (my ($genomic_align_block_id) = $sth->fetchrow_array) {
    # Avoid to return several times the same genomic_align_block
    next if (defined($all_genomic_align_block_ids->{$genomic_align_block_id}));
    $all_genomic_align_block_ids->{$genomic_align_block_id} = 1;

    # Lazy loading of genomic_align_blocks. All attributes are loaded on demand.
    my $this_genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                        -adaptor => $self,
                        -dbID => $genomic_align_block_id,
                        -method_link_species_set_id => $method_link_species_set_id,
                );
    push(@{$genomic_align_blocks}, $this_genomic_align_block);
  }
  
  return $genomic_align_blocks;
}


=head2 retrieve_all_direct_attributes

  Arg  1     : Bio::EnsEMBL::Compara::GenomicAlignBlock $genomic_align_block
  Example    : $genomic_align_block_adaptor->retrieve_all_direct_attributes($genomic_align_block)
  Description: Retrieve the all the direct attibutes corresponding to the dbID of the
               Bio::EnsEMBL::Compara::GenomicAlignBlock object. It is used after lazy fetching
               of the object for populating it when required.
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : 
  Caller     : none

=cut

sub retrieve_all_direct_attributes {
  my ($self, $genomic_align_block) = @_;

  my $sql = qq{
                SELECT
                    method_link_species_set, score, perc_id, length
                FROM
                    genomic_align_block
                WHERE
                    genomic_align_block_id = ?
        };

  my $sth = $self->prepare($sql);
  $sth->execute($genomic_align_block->dbID);
  my ($method_link_species_set_id, $score, $perc_id, $length) = $sth->fetchrow_array();
  
  ## Populate the object
  $genomic_align_block->adaptor($self);
  $genomic_align_block->method_link_species_set_id($method_link_species_set_id);
  $genomic_align_block->score($score);
  $genomic_align_block->perc_id($perc_id);
  $genomic_align_block->length($length);

  return $genomic_align_block;
}


1;
