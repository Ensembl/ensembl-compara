
#
# EnsEMBL module for Bio::EnsEMBL::Orthology::Score
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Orthology::Score 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Orthology::Score;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Root;

@ISA = qw(Bio::EnsEMBL::Root);

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
 Function: getset for score value
 Returns : value of score
 Args    : newvalue (optional)

=cut

sub score{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'score'} = $value;
   }
   return $self->{'score'};

}

