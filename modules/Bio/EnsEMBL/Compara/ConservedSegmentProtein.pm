
#
# EnsEMBL module for Bio::EnsEMBL::Orthology::ConservedSegmentProtein
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Orthology::ConservedSegmentProtein 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Orthology::ConservedSegmentProtein;
use vars qw(@ISA);
use strict;

# Object preamble - inheriets from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);

sub new {
    my ($class,$adaptor,@args) = @_;

    my $self = {};
    bless $self,$class;


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

=head2 conserved_segment
 Title   : conserved_segment
 Usage   : $obj->conserved_segment($newval) 
 Function: getset for conserved_segment 
 Returns : Bio::EnsEMBL::Orthology::Conserved_segment object
 Args    : Bio::EnsEMBL::Orthology::Conserved_segment 

=cut

sub conserved_segment{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      if (! $value->isa('Bio::EnsEMBL::Orthology::Conserved_segment') {
          $self->throw("Bio::EnsEMBL::Orthology::ConservedSegmentProtein needs a Bio::EnsEMBL::Orthology::Conserved_segment!"));
      }
   $self->{'conserved_segment'} = $value;
   }
   return $self->{'conserved_segment'};

}

=head2 protein
 Title   : protein
 Usage   : $obj->protein($newval) 
 Function: getset for protein 
 Returns : Bio::EnsEMBL::Orthology::Protein object
 Args    : Bio::EnsEMBL::Orthology::Protein 

=cut

sub protein{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      if (! $value->isa('Bio::EnsEMBL::Orthology::Protein') {
          $self->throw("Bio::EnsEMBL::Orthology::ConservedSegmentProtein needs a Bio::EnsEMBL::Orthology::Protein!"));
      }
   $self->{'protein'} = $value;
   }
   return $self->{'protein'};

}

