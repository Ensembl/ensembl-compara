
#
# Ensembl module for Bio::EnsEMBL::Compara::ProteinDB
#
# Cared for by EnsEMBL <www.ensembl.org>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::ProteinDB - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR - Ewan Birney

This modules is part of the Ensembl project http://www.ensembl.org

=head1 CONTACT
Email ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::ProteinDB;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::Root::RootI;
use Bio::EnsEMBL::DBLoader;

@ISA = qw(Bio::Root::RootI);

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

=head2 fetch_peptide_seq

 Title   : fetch_peptide_seq
 Usage   : $obj->fetch_peptide_seq($peptide)
 Function: 
 Example : 
 Returns : Bio::PrimarySeq Obj
 Args    : newvalue (optional)

=cut

sub fetch_peptide_seq{

   my ($self,$value) = @_;

   if (!defined $value){
      $self->throw("You need to provide an accession id of the protein you're trying to fetch");
   }

   my $seq;
   if ($self->db_adaptor->isa('Bio::EnsEMBL::DB::ObjI')){
      $seq = $self->db_adaptor->get_Protein_Adaptor->fetch_Protein_by_translationId($value);
   }elsif ($self->db_adaptor->isa('Bio::DB::SQL::DBAdaptor')){
      $seq = $self->db_adaptor->get_SeqAdaptor->fetch_by_db_and_accession($self->name,$value);
   }else{
      $self->warn("Don't know how to fetch protein seq using ".$self->db_adaptor.". Unable to fetch seq");
      return 0;
   }
   return $seq;
}

1;
