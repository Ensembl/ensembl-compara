
#
# Ensembl module for Bio::EnsEMBL::Compara::ExternalViewAlign
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::ExternalViewAlign - View alignment as if it is a sequence feature from a particular species

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


package Bio::EnsEMBL::Compara::ExternalViewAlign;
use vars qw(@ISA);
use strict;

use Bio::SeqFeatureI;

# Object preamble - inherits from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::SeqFeatureI Bio::Root::RootI);

# new() is written here 

sub new {
  my($class,@args) = @_;

    my $self = {};
    bless $self,$class;

# set stuff in self from @args
    return $self;
}


=head2 start

 Title   : start
 Usage   : $obj->start($newval)
 Function: 
 Example : 
 Returns : value of start
 Args    : newvalue (optional)


=cut

sub start{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'start'} = $value;
    }
    return $self->{'start'};

}

=head2 end

 Title   : end
 Usage   : $obj->end($newval)
 Function: 
 Example : 
 Returns : value of end
 Args    : newvalue (optional)


=cut

sub end{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'end'} = $value;
    }
    return $self->{'end'};

}

=head2 strand

 Title   : strand
 Usage   : $obj->strand($newval)
 Function: 
 Example : 
 Returns : value of strand
 Args    : newvalue (optional)


=cut

sub strand{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'strand'} = $value;
    }
    return $self->{'strand'};

}

=head2 seqname

 Title   : seqname
 Usage   : $obj->seqname($newval)
 Function: 
 Example : 
 Returns : value of seqname
 Args    : newvalue (optional)


=cut

sub seqname{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'seqname'} = $value;
    }
    return $self->{'seqname'};

}


=head2 align

 Title   : align
 Usage   : $obj->align($newval)
 Function: 
 Example : 
 Returns : value of align
 Args    : newvalue (optional)


=cut

sub align{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'align'} = $value;
    }
    return $self->{'align'};

}


1;
