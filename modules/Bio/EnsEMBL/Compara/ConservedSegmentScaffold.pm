
#
# EnsEMBL module for Bio::EnsEMBL::Orthology::ConservedSegmentScaffold
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Orthology::ConservedSegmentScaffold 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Orthology::ConservedSegmentScaffold;
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
          $self->throw("Bio::EnsEMBL::Orthology::ConservedSegmentScaffold needs a Bio::EnsEMBL::Orthology::Conserved_segment!"));
      }
   $self->{'conserved_segment'} = $value;
   }
   return $self->{'conserved_segment'};

}

=head2 scaffold
 Title   : scaffold
 Usage   : $obj->scaffold($newval) 
 Function: getset for scaffold 
 Returns : Bio::EnsEMBL::Orthology::Scaffold object
 Args    : Bio::EnsEMBL::Orthology::Scaffold 

=cut

sub scaffold{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      if (! $value->isa('Bio::EnsEMBL::Orthology::Scaffold') {
          $self->throw("Bio::EnsEMBL::Orthology::ConservedSegmentScaffold needs a Bio::EnsEMBL::Orthology::Scaffold!"));
      }
   $self->{'scaffold'} = $value;
   }
   return $self->{'scaffold'};

}

=head2 seq_start
 Title   : seq_start
 Usage   : $obj->seq_start($newval) 
 Function: getset for seq_start value
 Returns : value of seq_start
 Args    : newvalue (optional)

=cut

sub seq_start{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'seq_start'} = $value;
   }
   return $self->{'seq_start'};

}

=head2 seq_end
 Title   : seq_end
 Usage   : $obj->seq_end($newval) 
 Function: getset for seq_end value
 Returns : value of seq_end
 Args    : newvalue (optional)

=cut

sub seq_end{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'seq_end'} = $value;
   }
   return $self->{'seq_end'};

}

=head2 strand
 Title   : strand
 Usage   : $obj->strand($newval) 
 Function: getset for strand value
 Returns : value of strand
 Args    : newvalue (optional)

=cut

sub strand{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'strand'} = $value;
   }
   return $self->{'strand'};

}

=head2 intervening_genes
 Title   : intervening_genes
 Usage   : $obj->intervening_genes($newval) 
 Function: getset for intervening_genes value
 Returns : value of intervening_genes
 Args    : newvalue (optional)

=cut

sub intervening_genes{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'intervening_genes'} = $value;
   }
   return $self->{'intervening_genes'};

}

=head2 size
 Title   : size
 Usage   : $obj->size($newval) 
 Function: getset for size value
 Returns : value of size
 Args    : newvalue (optional)

=cut

sub size{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'size'} = $value;
   }
   return $self->{'size'};

}

