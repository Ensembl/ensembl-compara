#
# Ensembl module for Bio::EnsEMBL::Compara::GenomicAlignGroup
#
# Copyright Javier Herrero
#
# You may distribute this module under the same terms as perl itself

# pod documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::GenomicAlignGroup - Defines groups of genomic aligned sequences

=head1 SYNOPSIS
  
  use Bio::EnsEMBL::Compara::GenomicAlignGroup;
  
  my $genomic_align_group = new Bio::EnsEMBL::Compara::GenomicAlignGroup (
          -adaptor => $genomic_align_group_adaptor,
          -genomic_align_array => [$genomic_align1, $genomic_align2...]
      );

SET VALUES
  $genomic_align_group->adaptor($gen_ali_blk_adaptor);
  $genomic_align_group->dbID(12);
  $genomic_align_group->genomic_align_array([$genomic_align1, $genomic_align2]);

GET VALUES
  my $genomic_align_group_adaptor = $genomic_align_group->adaptor();
  my $dbID = $genomic_align_group->dbID();
  my $genomic_aligns = $genomic_align_group->genomic_align_array();

=head1 DESCRIPTION

=over

=item dbID

corresponds to genomic_align_group.group_id

=item adaptor

Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object to access DB

=item genomic_align_array

listref of Bio::EnsEMBL::Compara::DBSQL::GenomicAlign objects corresponding to this
Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroup object

=back

=head1 AUTHOR

Javier Herrero (jherrero@ebi.ac.uk)

This modules is part of the Ensembl project http://www.ensembl.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::GenomicAlignGroup;
use strict;

# Object preamble
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);


=head2 new (CONSTRUCTOR)

  Arg[1]     : a reference to a hash where keys can be:
                 -adaptor
                 -dbID
                 -type
                 -genomic_align_array
  Example    : my $genomic_align_block =
                   new Bio::EnsEMBL::Compara::GenomicAlignBlock(
                       -adaptor => $genomic_align_group_adaptor,
                       -type => "pairwise",
                       -genomic_align_array => [$genomic_align1, $genomic_align2...]
                   );
  Description: Creates a new GenomicAligngroup object
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroup
  Exceptions : none
  Caller     : general

=cut

sub new {
  my($class, @args) = @_;
  
  my $self = {};
  bless $self,$class;
    
  my ($adaptor, $dbID, $type, $genomic_align_array) = 
    rearrange([qw(
        ADAPTOR DBID TYPE GENOMIC_ALIGN_ARRAY)], @args);

  $self->adaptor($adaptor) if (defined ($adaptor));
  $self->dbID($dbID) if (defined ($dbID));
  $self->type($type) if (defined ($type));
  $self->genomic_align_array($genomic_align_array) if (defined($genomic_align_array));

  return $self;
}


sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
}


=head2 adaptor

  Arg [1]    : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor $adaptor
  Example    : my $gen_ali_grp_adaptor = $genomic_align_block->adaptor();
  Example    : $genomic_align_block->adaptor($gen_ali_grp_adaptor);
  Description: Getter/Setter for the adaptor this object uses for database
               interaction.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object
  Exceptions : thrown if $adaptor is not a
               Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object
  Caller     : general

=cut

sub adaptor {
  my ($self, $adaptor) = @_;

  if (defined($adaptor)) {
    throw("$adaptor is not a Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor object")
        unless ($adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignGroupAdaptor"));
    $self->{'adaptor'} = $adaptor;
  }

  return $self->{'adaptor'};
}


=head2 dbID

  Arg [1]    : integer $dbID
  Example    : my $dbID = $genomic_align_group->dbID();
  Example    : $genomic_align_group->dbID(12);
  Description: Getter/Setter for the attribute dbID
  Returntype : integer
  Exceptions : none
  Caller     : general

=cut

sub dbID {
  my ($self, $dbID) = @_;

  if (defined($dbID)) {
    $self->{'dbID'} = $dbID;
  }

  return $self->{'dbID'};
}


=head2 type

  Arg [1]    : string $type
  Example    : my $type = $genomic_align_group->type();
  Example    : $genomic_align_group->type("pairwise");
  Description: Getter/Setter for the attribute type
  Returntype : string
  Exceptions : none
  Caller     : general

=cut

sub type {
  my ($self, $type) = @_;

  if (defined($type)) {
    $self->{'type'} = $type;
  }

  return $self->{'type'};
}


=head2 genomic_align_array
 
  Arg [1]    : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Example    : $genomic_aligns = $genomic_align_group->genomic_align_array();
               $genomic_align_group->genomic_align_array([$genomic_align1, $genomic_align2]);
  Description: get/set for attribute genomic_align_array
  Returntype : array reference containing Bio::EnsEMBL::Compara::GenomicAlign objects
  Exceptions : none
  Caller     : general
 
=cut

sub genomic_align_array {
  my ($self, $genomic_align_array) = @_;
 
  if (defined($genomic_align_array)) {
    foreach my $genomic_align (@$genomic_align_array) {
      throw("$genomic_align is not a Bio::EnsEMBL::Compara::GenomicAlign object")
          unless ($genomic_align->isa("Bio::EnsEMBL::Compara::GenomicAlign"));
    }
    $self->{'genomic_align_array'} = $genomic_align_array;
  }
  
  return $self->{'genomic_align_array'};
}

1;
