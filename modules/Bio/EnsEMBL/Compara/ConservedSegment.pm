
#
# EnsEMBL module for Bio::EnsEMBL::Orthology::ConservedSegment
#
# Cared for by EnsEMBL (www.ensembl.org)
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Orthology::ConservedSegment 

=head1 SYNOPSIS


=head1 DESCRIPTION


=head1 CONTACT

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Orthology::ConservedSegment;
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

=head2 conserved_genes
 Title   : conserved_genes
 Usage   : $obj->conserved_genes($newval) 
 Function: getset for conserved_genes value
 Returns : value of conserved_genes
 Args    : newvalue (optional)

=cut

sub conserved_genes{
   my $self = shift;

   if( @_ ) {
      my $value = shift;
      $self->{'conserved_genes'} = $value;
   }
   return $self->{'conserved_genes'};

}

