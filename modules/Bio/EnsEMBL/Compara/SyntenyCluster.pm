
#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyCluster.pm
#
# Cared for by ewan <ensembl-dev@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SyntenyCluster.pm - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyCluster.pm;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::RootI

use Bio::Root::RootI;


@ISA = qw(Bio::Root::RootI);

sub new {
  my($class,@args) = @_;
  
  my $self = {};

  bless $self,$class;
  
  return $self;
}


=head2 each_SyntenyRegion

 Title   : each_SyntenyRegion
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub each_SyntenyRegion{
   my ($self,@args) = @_;

   if( defined $self->{'_synteny_region'} ) {
       return @{$self->{'_synteny_region'}};
   }

   $self->{'_synteny_region'} = [];

   my @region = $self->adaptor->db->get_SyntenyRegionAdaptor->fetch_by_cluster_id($self->dbID);
   push(@{$self->{'_synteny_region'}},@region);

   return @region;
}

=head2 each_GenomicAlign

 Title   : each_GenomicAlign
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub each_GenomicAlign{
   my ($self,@args) = @_;

   if( defined $self->{'_align'} ) {
       return @{$self->{'_align'}};
   }

   $self->{'_align'} = [];

   my @align = $self->adaptor->db->get_GenomicAlignAdaptor->fetch_by_cluster_id($self->dbID);
   push(@{$self->{'_align'}},@align);

   return @align;

}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function: 
 Returns : value of dbID
 Args    : newvalue (optional)


=cut

sub dbID{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'dbID'} = $value;
    }
    return $obj->{'dbID'};

}

=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};

}
