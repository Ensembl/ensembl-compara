#
# EnsEMBL module for Bio::EnsEMBL::Compara::ConservedCluster
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::ConservedCluster 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::ConservedCluster;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);

sub new {
    my ($class,@args) = @_;

    my $self = {};
    bless $self,$class;

    $self->{'_conserved_segment_array'} = [];

    my ($dbID,$conserved_gene_families,$conserved_segments,$adaptor) = 
       $self->_rearrange([qw( DBID
                              CONSERVED_GENE_FAMILIES
                              CONSERVED_SEGMENTS
                              ADAPTOR
                         )],@args);

    if (defined $conserved_gene_families){
      $self->conserved_gene_families($conserved_gene_families);
    }

    foreach my $cs (@{$conserved_segments}){
      $self->add_conserved_segment($cs);
    } 

    if (defined $adaptor){
      $self->adaptor($adaptor);
    }

    return $self;
}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function:
 Returns : value of dbID
 Args    : newvalue (optional)

=cut

sub dbID {
   my $self = shift;
   if( @_ ) {
      my $value = shift;
      $self->{'dbID'} = $value;
   }
   return $self->{'dbID'};

}

=head2 conserved_gene_families
 Title   : conserved_gene_families
 Usage   : $obj->conserved_gene_families($newval) 
 Function: getset for conserved_gene_families value
 Returns : value of conserved_gene_families
 Args    : newvalue (optional)

=cut

sub conserved_gene_families{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'conserved_gene_families'} = $value;
   }
   return $self->{'conserved_gene_families'};

}

=sub add_conserved_segmemt{
 Usage   : $obj->add_conserved_segment($conserved_segment)
 Function:
 Function:
 Returns :
 Args    :
 
 
=cut
 
sub add_conserved_segment{
 
    my ($self,$conserved_segment) = @_;
 
    $self->throw("Trying to add conserved_segment without supplying argument") 
           unless ($conserved_segment->isa ("Bio::EnsEMBL::Compara::ConservedSegment"));;

    $conserved_segment->conserved_cluster_id($self->dbID);
 
    push (@{$self->{'_conserved_segment_array'}},$conserved_segment);
 
}

=head2 get_all_conserved_segments

 Title   : get_all_conserved_segments
 Usage   : $obj->get_all_conserved_segments
 Function:
 Returns : 
 Args    : 

=cut

sub get_all_conserved_segments{

    my ($self) = @_;
    
    return  @{$self->{'_conserved_segment_array'}};

}

=head2 adaptor
 
 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: Getset for adaptor object
 Returns : Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor
 Args    : Bio::EnsEMBL::Compara::DBSQL::ProteinAdaptor
 
 
=cut
 
sub adaptor{
   my $obj = shift;
   if( @_ ) {
      my $value = shift;
      $obj->{'adaptor'} = $value;
    }
    return $obj->{'adaptor'};
 
}

1;
