#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ConservedClusterAdaptor
#
# Cared for by EnsEMBL <www.ensembl.org>
#
# Copyright GRL 
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ConservedClusterAdaptor - DESCRIPTION of Object

=head1 SYNOPSIS

Give standard usage here

=head1 DESCRIPTION

Describe the object here

=head1 AUTHOR  

This modules is part of the Ensembl project http://www.ensembl.org

Email ensembl-dev@ebi.ac.uk

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut


# Let the code begin...


package Bio::EnsEMBL::Compara::DBSQL::ConservedClusterAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);


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

   if( !defined $dbid) {
       $self->throw("Must fetch by dbid");
   }

   my $sth = $self->prepare("select conserved_gene_families
                             from conserved_cluster where conserved_cluster_id = $dbid");
   $sth->execute;

   my ($conserved_gene_families) = $sth->fetchrow_array();

   if( !defined $conserved_gene_families) {
       $self->throw("No conserved cluster with this dbID $dbid");
   }

   my $sth = $self->prepare("select conserved_segment_id from conserved_segment 
                             where conserved_cluster_id = $dbid");
   $sth->execute;

   my @conserved_segments;
   my $cs_adaptor = $self->db->get_ConservedSegmentAdaptor;
 
   while (my ($cs_id) = $sth->fetchrow_array){
      my $cs = $cs_adaptor->fetch_by_dbID($cs_id);
      push (@conserved_segments,$cs);
   }


   my $conserved_cluster= Bio::EnsEMBL::Compara::ConservedCluster->new( 	-dbid 	=> $dbid,
														-conserved_gene_families=> $conserved_gene_families,
														-conserved_segments=> @conserved_segments
														               );

   return $conserved_cluster;

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
   my ($self,$conserved_cluster) = @_;

   if( !$conserved_cluster->isa ('Bio::EnsEMBL::Compara::ConservedCluster')) {
       $self->throw("$conserved_cluster must be a 'Bio::EnsEMBL::Compara::Conserved_Cluster'");
   }

   my @conserved_segments = $conserved_cluster->get_all_conserved_segments;
 
   $self->throw ("No Conserved segments found on this conserved_segment, not storing!")
          unless (@conserved_segments);

   my $sth = $self->prepare("insert into conserved_cluster(conserved_gene_families) values (?)");
   $sth->execute($conserved_cluster->conserved_gene_families);

   $conserved_cluster->dbID($sth->{'mysql_insertid'});
   $conserved_cluster->adaptor($self);
   
   my $cs_adaptor = $self->db->get_ConservedSegmentAdaptor;

   foreach my $cs (@conserved_segments){
     $cs->conserved_cluster_id($conserved_cluster->dbID);
     $cs_adaptor->store($cs);
   } 

   return $conserved_cluster->dbID;
}


1;
