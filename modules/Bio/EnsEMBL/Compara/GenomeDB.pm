
#
# Ensembl module for Bio::EnsEMBL::Compara::GenomeDB
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::GenomeDB - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::GenomeDB;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Root;
use Bio::EnsEMBL::DBLoader;

@ISA = qw(Bio::EnsEMBL::Root);

# new() is written here 

sub new {
    my($class,@args) = @_;
    
    my $self = {};
    bless $self,$class;
    
# set stuff in self from @args
    return $self;
}


=head2 db_adaptor

 Title   : db_adaptor
 Usage   :
 Function:
 Example : returns the db_adaptor
 Returns : 
 Args    :


=cut

sub db_adaptor{
   my ($self) = @_;

   if( !defined $self->{'_db_adaptor'} ) {
       # this will throw if it can't build it
       $self->{'_db_adaptor'} = Bio::EnsEMBL::DBLoader->new($self->locator);
   }

   return $self->{'_db_adaptor'};
}


=head2 locator

 Title   : locator
 Usage   : $obj->locator($newval)
 Function: 
 Example : 
 Returns : value of locator
 Args    : newvalue (optional)

=cut

sub locator{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'locator'} = $value;
    }
    return $self->{'locator'};

}

=head2 name

 Title   : name
 Usage   : $obj->name($newval)
 Function: 
 Example : 
 Returns : value of name
 Args    : newvalue (optional)


=cut

sub name{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'name'} = $value;
    }
    return $self->{'name'};

}


=head2 dbID

 Title   : dbID
 Usage   : $obj->dbID($newval)
 Function: 
 Example : 
 Returns : value of dbID
 Args    : newvalue (optional)


=cut

sub dbID{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'dbID'} = $value;
    }
    return $self->{'dbID'};

}


=head2 adaptor
 
  Arg [1]    : (optional) Bio::EnsEMBL::Compara::GenomeDBAdaptor $adaptor
  Example    : $adaptor = $GenomeDB->adaptor();
  Description: Getter/Setter for the GenomeDB object adaptor used
               by this GenomeDB for database interaction.
  Returntype : Bio::EnsEMBL::Compara::GenomeDBAdaptor
  Exceptions : none
  Caller     : general
 
=cut
 
sub adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'adaptor'} = $value;
    }
    return $self->{'adaptor'};
}





























1;
