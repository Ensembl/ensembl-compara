
#
# EnsEMBL module for Bio::EnsEMBL::Orthology::ScoreProtein
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Orthology::ScoreProtein 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Orthology::ScoreProtein;
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

=head2 score
 Title   : score
 Usage   : $obj->score($newval) 
 Function: getset for score 
 Returns : Bio::EnsEMBL::Orthology::Score object
 Args    : Bio::EnsEMBL::Orthology::Score 

=cut

sub score{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      if (! $value->isa('Bio::EnsEMBL::Orthology::Score') {
          $self->throw("Bio::EnsEMBL::Orthology::ScoreProtein needs a Bio::EnsEMBL::Orthology::Score!"));
      }
   $self->{'score'} = $value;
   }
   return $self->{'score'};

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
          $self->throw("Bio::EnsEMBL::Orthology::ScoreProtein needs a Bio::EnsEMBL::Orthology::Protein!"));
      }
   $self->{'protein'} = $value;
   }
   return $self->{'protein'};

}

