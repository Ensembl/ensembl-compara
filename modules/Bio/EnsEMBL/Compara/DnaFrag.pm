
#
# Ensembl module for Bio::EnsEMBL::Compara::DnaFrag.pm
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright Ewan Birney
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DnaFrag - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::DnaFrag;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);

# new() is written here 

sub new {
  my($class,@args) = @_;

  my $self = {};

  bless $self,$class;

   my ($name, $contig,$genomedb,$adaptor,$dbID) = $self->_rearrange([qw( NAME
                                                                       	CONTIG 
                                                                       	GENOMEDB
						 	         	ADAPTOR
									DBID)],@args);

   if( defined $name) {
     	 $self->name($name);
   }
   if( defined $contig) {
     $self->contig($contig);
   }
   
   if (defined $genomedb){
     $self->genomedb($genomedb);
   }

   if (defined $adaptor){
     $self->adaptor($adaptor);
   }
     
   if (defined $dbID) {
     $self->dbID($dbID);
   }


# set stuff in self from @args
    return $self;
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


=head2 contig

 Title   : contig
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub contig{
   my ($self) = @_;

   if( !defined $self->{'_contig'} ) {
       $self->{'_contig'} = $self->genomedb->ensembl_db->get_Contig($self->name);
   }

   return $self->{'_contig'};
}



=head2 genomedb

 Title   : genomedb
 Usage   : $obj->genomedb($newval)
 Function: 
 Example : 
 Returns : value of genomedb
 Args    : newvalue (optional)


=cut

sub genomedb{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'genomedb'} = $value;
    }
    return $self->{'genomedb'};

}

=head2 adaptor

 Title   : adaptor
 Usage   : $obj->adaptor($newval)
 Function: 
 Example : 
 Returns : value of adaptor
 Args    : newvalue (optional)


=cut

sub adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'adaptor'} = $value;
    }
    return $self->{'adaptor'};

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

1;


