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

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use vars qw(@ISA);
use strict;

use Bio::EnsEMBL::DBSQL::DBConnection;

@ISA = qw( Bio::EnsEMBL::DBSQL::DBConnection );

=head2 get_SyntenyAdaptor

 Title   : get_SyntenyAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_SyntenyAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::SyntenyAdaptor");
}

=head2 get_GenomeDBAdaptor

 Title   : get_GenomeDBAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_GenomeDBAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor");
}

=head2 get_DnaFragAdaptor

 Title   : get_DnaFragAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_DnaFragAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor");
}

=head2 get_GenomicAlignAdaptor

 Title   : get_GenomicAlignAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_GenomicAlignAdaptor{
  my ($self) = @_;
   
  return 
    $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::GenomicAlignAdaptor");
}


=head2 get_HomologyAdaptor

 Title   : get_HomologyAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub get_HomologyAdaptor{
   my ($self) = @_;

   return $self->_get_adaptor("Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor");
}


=head2 get_SyntenyRegionAdaptor

 Title   : get_SyntenyRegionAdaptor
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


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

1;
