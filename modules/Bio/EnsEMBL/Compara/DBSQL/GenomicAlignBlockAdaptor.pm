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


@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor Bio::EnsEMBL::Compara::DBSQL::DBAdaptor);

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
  Exceptions : - not stored linked dnafrag objects throw.
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
  my $genomic_align_adaptor = $self->get_GenomicAlignAdaptor;
  $genomic_align_adaptor->store($genomic_align_block->genomic_align_array);

  return $genomic_align_block;
}


=head2 fetch_by_dbID

  Arg  1     : integer $genomic_align_block_id
  Example    : my $genomic_align_block = $genomic_align_block?adaptor->fetch_by_dbID(1)
  Description: Retrieve the correspondig
               Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Returntype : Bio::EnsEMBL::Compara::GenomicAlignBlock object
  Exceptions : Returns undef if no matching
               Bio::EnsEMBL::Compara::GenomicAlignBlock object can be retrieved
  Caller     : none

=cut

sub fetch_by_dbID {
  my ($self, $dbID) = @_;
  my $genomic_align_block; # returned object
  
  my $mlssa = $self->get_MethodLinkSpeciesSetAdaptor;
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
  my ($method_link_species_set, $score, $perc_id, $length) = $sth->fetchrow_array();
  
  ## Create the object
  $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                        -adaptor => $self,
                        -dbID => $dbID,
                        -method_link_species_set => $mlssa->fetch_by_dbID($method_link_species_set),
                        -score => $score,
                        -perc_id => $perc_id,
                        -length => $length
                );

  return $genomic_align_block;
}


1;
