
#
# Ensembl module for Bio::EnsEMBL::Compara::MappedExon
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::MappedExon - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

Email birney@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::MappedExon;
use Bio::EnsEMBL::Exon;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Exon;

@ISA = qw(Bio::EnsEMBL::Exon);


=head2 rank

 Title   : rank
 Usage   : $obj->rank($newval)
 Function: 
 Example : 
 Returns : value of rank
 Args    : newvalue (optional)


=cut

sub rank{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'rank'} = $value;
    }
    return $self->{'rank'};

}

=head2 warped

 Title   : warped
 Usage   : $obj->warped($newval)
 Function: 
 Example : 
 Returns : value of warped
 Args    : newvalue (optional)


=cut

sub warped{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'warped'} = $value;
    }
    return $self->{'warped'};

}




1;
