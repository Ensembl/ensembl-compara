
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

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Argument;

sub new {
  my($class,@args) = @_;

  my $self = {};

  bless $self,$class;

  my ($name,$contig,$genomedb,$type,$adaptor,$dbID) =
    rearrange([qw(NAME CONTIG GENOMEDB TYPE ADAPTOR DBID)],@args);

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

   if (defined $type){
     $self->type($type);
   }

   if (defined $dbID) {
     $self->dbID($dbID);
   }


# set stuff in self from @args
    return $self;
}

sub new_fast {
  my $class = shift;
  my $hashref = shift;

  return bless $hashref, $class;
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

sub contig {
   my ($self) = @_;

   if( !defined $self->{'_contig'} ) {
     my $core_dbadaptor = $self->genomedb->db_adaptor;
     if ($self->type eq "RawContig") {
       $self->{'_contig'} = $core_dbadaptor->get_SliceAdaptor->fetch_by_region('seqlevel', $self->name);
     }
     elsif ($self->type eq "VirtualContig") {
       my ($chr,$start,$end) = split /\./, $self->name;
       $self->{'_contig'} = $core_dbadaptor->get_SliceAdaptor->fetch_by_region('toplevel',$start,$end);
     } 
     elsif ($self->type eq "Chromosome") {
       $self->{'_contig'} = $core_dbadaptor->get_SliceAdaptor->fetch_by_region('toplevel',$self->name);
     } 
     else {
       throw ("Can't fetch contig of ".$self->name." with type ".$self->type);
     }
   }
   
   return $self->{'_contig'};
}

sub slice {
  my ($self) = @_;
  
  unless (defined $self->{'_slice'}) {
    my $dba = $self->genomedb->db_adaptor;
    $self->{'_slice'} = $dba->get_SliceAdaptor->fetch_by_region($self->type, $self->name);
  }

  return $self->{'_slice'};
}

=head2 genomedb

 Title   : genomedb
 Usage   : $obj->genomedb($newval)
 Function: 
 Example : 
 Returns : value of genomedb
 Args    : newvalue (optional)


=cut

sub genomedb {
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'genomedb'} = $value;
    }
    return $self->{'genomedb'};

}

=head2 type

 Title   : type
 Usage   : $obj->type($newval)
 Function: 
 Example : 
 Returns : value of type
 Args    : newvalue (optional)


=cut

sub type{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'type'} = $value;
    }
    return $self->{'type'};

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



=head2 start
 
  Arg [1]    : int
  Example    : $dnafrag->start(42);
  Description: Getter/Setter for the start attribute
  Returntype : int
  Exceptions : none
  Caller     : general

=cut
 
sub start{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'start'} = $value;
    }
    return $self->{'start'};
}



=head2 end
 
  Arg [1]    : int
  Example    : $dnafrag->end(42);
  Description: Getter/Setter for the start attribute
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut
 
sub end{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'end'} = $value;
    }
    return $self->{'end'};
}

=head2 length
 
  Arg [1]    : int
  Example    : $dnafrag->length;
  Description: Getter for the length attribute
  Returntype : int
  Exceptions : none
  Caller     : general
 
=cut
 
sub length{
  my ($self) = @_;
  unless (defined $self->{'length'}) {
    $self->{'length'} = $self->{'end'} - $self->{'start'} + 1;
  }
   return $self->{'length'};
}

1;


