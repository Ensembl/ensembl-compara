#
# BioPerl module for DBSQL::Obj
#
# Cared for by Ewan Birney <birney@sanger.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor

=head1 SYNOPSIS

    $db = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
        -user   => 'root',
        -dbname => 'pog',
        -host   => 'caldy',
        -driver => 'mysql',
        );


=head1 DESCRIPTION

This object represents the handle for a comparative DNA alignment database

=head1 CONTACT

Post questions the the EnsEMBL developer list: <ensembl-dev@ebi.ac.uk>

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::DBConnection;

@ISA = qw( Bio::EnsEMBL::DBSQL::DBConnection );



=head2 get_SyntenyAdaptor

  Arg [1]    : none
  Example    : $sa = $dba->get_SyntenyAdaptor
  Description: Retrieves a synteny adaptor for this database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::SyntenyAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_SyntenyAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::SyntenyAdaptor");
}


=head2 get_GenomeDBAdaptor

  Arg [1]    : none
  Example    : $gdba = $dba->get_GenomeDBAdaptor
  Description: Retrieves an adaptor that can be used to obtain GenomeDB
               objects from this compara database.
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_GenomeDBAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor");
}



=head2 get_DnaFragAdaptor

  Arg [1]    : none
  Example    : $dfa = $dba->get_DnaFragAdaptor
  Description: Retrieves an adaptor that can be used to obtain DnaFrag objects
               from this compara database.
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub get_DnaFragAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor");
}



=head2 get_GenomicAlignAdaptor

  Arg [1]    : none
  Example    : $gaa = $dba->get_GenomicAlignAdaptor
  Description: Retrieves an adaptor for this database which can be used
               to obtain GenomicAlign objects
  Returntype : Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_GenomicAlignAdaptor{
  my ($self) = @_;

  return
    $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor");
}



=head2 get_HomologyAdaptor

  Arg [1]    : none
  Example    : $ha = $dba->get_HomologyAdaptor
  Description: Retrieves a HomologyAdaptor for this database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor
  Exceptions : general
  Caller     : none

=cut

sub get_HomologyAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor");
}



=head2 get_SyntenyRegionAdaptor

  Arg [1]    : none
  Example    : $sra = $dba->get_SyntenyRegionAdaptor
  Description: Retrieves a SyntenyRegionAdaptor for this database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_SyntenyRegionAdaptor{
   my ($self) = @_;

   return 
     $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::SyntenyRegionAdaptor");
}



=head2 get_DnaAlignFeatureAdaptor

  Arg [1]    : none
  Example    : $dafa = $dba->get_DnaAlignFeatureAdaptor;
  Description: Retrieves a DnaAlignFeatureAdaptor for this compara database
  Returntype : Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor
  Exceptions : none
  Caller     : general

=cut

sub get_DnaAlignFeatureAdaptor {
  my $self = shift;

  return 
   $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::DnaAlignFeatureAdaptor");
}



=head2 get_MetaContainer

  Arg [1]    : none
  Example    : $mc = $dba->get_MetaContainer
  Description: Retrieves an object that can be used to obtain meta information
               from the database.
  Returntype : Bio::EnsEMBL::DBSQL::MetaContainer
  Exceptions : none
  Caller     : general

=cut

sub get_MetaContainer {
    my $self = shift;

    return $self->_get_adaptor("Bio::EnsEMBL::DBSQL::MetaContainer");
}


1;
