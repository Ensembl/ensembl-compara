

#
# Ensembl module for Bio::EnsEMBL::Compara::SyntenyRegionAdaptor
#
# Cared for by Ewan Birney <birney@ebi.ac.uk>
#
# Copyright GRL and EBI
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::SyntenyRegionAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 CONTACT

Ensembl - ensembl-dev@ebi.ac.uk

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::SyntenyRegionAdaptor;
use vars qw(@ISA);
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::SyntenyRegion;
use strict;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);


=head2 fetch_by_dbID

 Title   : fetch_by_dbID
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_dbID{
   my ($self,$dbid) = @_;

   if( !defined $dbid ) {
       $self->throw("fetch_by_dbID with no dbID!");
   }

   my $sth = $self->prepare("select synteny_cluster_id,dnafrag_id,seq_start,seq_end from synteny_region where synteny_region_id = $dbid");

   my ($cluster,$dnafrag,$start,$end) = $sth->fetchrow_array();

   return $self->_new_region_from_array($dbid,$cluster,$dnafrag,$start,$end);
}

=head2 fetch_by_cluster_id

 Title   : fetch_by_cluster_id
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub fetch_by_cluster_id{
   my ($self,$cluster_id) = @_;

   if( !defined $cluster_id ) {
       $self->throw("fetch_by_cluster_id with no cluster_id!");
   }

   my $sth = $self->prepare("select synteny_region_id,dnafrag_id,seq_start,seq_end from synteny_region where synteny_cluster_id = $cluster_id");

   my @out;
   while( $ref  = $sth->fetchrow_arrayref() ) {
       my ($dbid,$dnafrag,$start,$end) = @$ref;
       push(@out,$self->_new_region_from_array($dbid,$cluster_id,$dnafrag,$start,$end));
   }
   
   return @out;
}


=head2 _new_region_from_array

 Title   : _new_region_from_array
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub _new_region_from_array{
   my ($self,$dbID,$cluster,$dnafrag,$start,$end) = @_;

   if( !defined $end ) {
       $self->throw("internal error - not enough args");
   }

   my $region = Bio::EnsEMBL::Compara::SyntenyRegion->new();
   $region->cluster_id($cluster);
   $region->dnafrag_id($dnafrag);
   $region->start($start);
   $region->end($end);
   $region->adaptor($self);
   $region->dbID($dbID);

   return $region;
}


=head2 store

 Title   : store
 Usage   :
 Function:
 Example :
 Returns : 
 Args    :


=cut

sub store{
   my ($self,$cluster_id,$region) = @_;

   if( !defined $region ) {
       $self->throw("store(cluster_id,region_object)");
   }

   if( !ref $region || !$region->isa("Bio::EnsEMBL::Compara::SyntenyRegion") ) {
       $self->throw("$region is not a SyntenyRegion");
   }

   my $sth = $self->prepare("insert into synteny_region (synteny_cluster_id,dnafrag_id,seq_start,seq_end) VALUES (?,?,?,?)");
   
   $sth->execute($cluster_id,$region->dnafrag_id,$region->seq_start,$region->seq_end);
   my $region_id = $sth->{'mysql_insertid'};
   
   $region->dbID($region_id);
   $region->adaptor($self);
   
   return $region_id;
}








