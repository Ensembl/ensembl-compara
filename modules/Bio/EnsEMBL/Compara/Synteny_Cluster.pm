# Cared for by Tania
#
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Synteny_Cluster -Object representing Synteny hits(for synteny) 

=head1 SYNOPSIS

    # $db is Bio::EnsEMBL::DB::Obj 

     #$hits is an array of Synteny_Hit object 
     my $synteny_cluster= Bio::EnsEMBL::Synteny_Cluster->new ( -dbID          => $syn_cluster_id,
                                                               -syn_hits      => $hits, 
                       					       -syn_desc      => 'hello world'
                                                               -adaptor       => $adaptor,
                                                             );



=head1 DESCRIPTION





=head1 CONTACT

kailan (calan@imcb.nus.edu.sg)
tania (tania@fugu-sg.org)

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::Synteny_Cluster;
use vars qw(@ISA);
use Bio::Root::RootI;

use strict;

# Object preamble - inheriets from Bio::Root::RootI

use Bio::Root::RootI;

@ISA = qw(Bio::Root::RootI);

# new() is written here

sub new {
  my($class,@args) = @_;

  my $self = {};
  bless $self,$class;
 
  my ($dbID, $syn_hits, $syn_desc, $adaptor) = $self->_rearrange([qw(    
                                                                     DBID 
								     SYN_HITS
                              					     SYN_DESC
                                                                     ADAPTOR
                                                                  )],@args);


   if( defined $syn_hits) {
     $self->syn_hits($syn_hits);
   }

   if (defined $syn_desc){
     $self->syn_desc($syn_desc);
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


=head2 syn_hits

 Title	 : syn_hits
 Usage	 : $obj->syn_hits($newval)
 Function:
 Example :
 Returns : value of syn_hits
 Args	 : newvalue (optional)


=cut

sub syn_hits {
   my ($self,$val) = @_;
   
   if (defined $val){
      $self->{'_syn_hits'} = $val;
   }
   return $self->{'_syn_hits'}; 
}

=head2 syn_desc

 Title	 : syn_desc
 Usage	 : $obj->syn_descr($newval)
 Function:
 Example :
 Returns : value of syn_desc
 Args	 : newvalue (optional)


=cut

sub syn_desc{
	my ($obj,$value) = @_;
	if( defined $value) {
	$obj->{'syn_desc'} = $value;
    }
	return $obj->{'syn_desc'};

}

=head2 dbID

 Title	 : dbID
 Usage	 : $obj->dbID($newval)
 Function: 
 Example : 
 Returns : value of dbID
 Args 	 : newvalue (optional)


=cut

sub dbID{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'dbID'} = $value;
    }
    return $self->{'dbID'};

}

=head2 adaptor

 Title	 : adaptor
 Usage	 : $obj->adaptor($newval)
 Function: 
 Example : 
 Returns : value of adaptor
 Args 	 : newvalue (optional)


=cut

sub adaptor{
   my ($self,$value) = @_;
   if( defined $value) {
      $self->{'adaptor'} = $value;
    }
    return $self->{'adaptor'};

}

1;
