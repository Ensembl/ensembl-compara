#
# Ensembl module for Bio::EnsEMBL::Compara::DBSQL::ConservedSegmentAdaptor
#
# Cared for by EnsEMBL <www.ensembl.org>
#
# Copyright GRL 
#
# You may distribute this module under the same terms as perl itself

# POD documentation - main docs before the code

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::ConservedSegmentAdaptor - DESCRIPTION of Object

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


package Bio::EnsEMBL::Compara::DBSQL::ConservedSegmentAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble

use Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::ConservedSegment;

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

   my $sth = $self->prepare("select c.conserved_cluster_id,d.genome_db_id,d.dnafrag_id,c.seq_start,c.seq_end,c.intervening_genes
                             from conserved_segment c, dnafrag d 
                             where d.dnafrag_id = c.dnafrag_id
                             and conserved_segment_id = $dbid");
   $sth->execute;

   my ($conserved_cluster_id,$genome_db_id,$dnafrag_id,$seq_start,$seq_end,$intervening_genes) = $sth->fetchrow_array();

   if( !defined $conserved_cluster_id) {
       $self->throw("No conserved segment associated with this dbID $dbid");
   }


   my $conserved_segment = Bio::EnsEMBL::Compara::ConservedSegment->new( 	-dbid 	=> $dbid,
														-genome_db_id	=> $genome_db_id,
														-conserved_cluster_id=> $conserved_cluster_id,
														-seq_start	=> $seq_start,
														-seq_end	=> $seq_end,
														-intervening_genes => $intervening_genes,
														-adaptor => $self,
														-dnafrag_id	=> $dnafrag_id);

   $sth = $self->prepare("Select protein_id from conserved_segment_protein 
                  where conserved_segment_id = $dbid");
   $sth->execute();

   while (my ($prot_id) = $sth->fetchrow_array){
      $conserved_segment->add_Protein_id($prot_id);
   };

   return $conserved_segment;

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
   my ($self,$conserved_segment) = @_;

   if( !$conserved_segment->isa ('Bio::EnsEMBL::Compara::ConservedSegment')) {
       $self->throw("$conserved_segment must be a 'Bio::EnsEMBL::Compara::ConservedSegment'");
   }

   $self->throw("Conserved segment has no conserved_cluster_id! Store conserved cluster first.") 
          unless defined ($conserved_segment->conserved_cluster_id);

   my @protein_ids = $conserved_segment->get_all_Protein_ids;
   $self->throw("Conserved_segment has no protein_ids!") unless @protein_ids;

   my $sth = $self->prepare("insert into conserved_segment
                            (conserved_cluster_id, dnafrag_id, seq_start, seq_end,
                             intervening_genes) values (?,?,?,?,?)");


   $sth->execute($conserved_segment->conserved_cluster_id,$conserved_segment->dnafrag_id,$conserved_segment->seq_start,$conserved_segment->seq_end,$conserved_segment->intervening_genes);

   $conserved_segment->dbID($sth->{'mysql_insertid'});
   $conserved_segment->adaptor($self);

   foreach my $prot_id (@protein_ids){
     my $sth = $self->prepare("insert into conserved_segment_protein (conserved_segment_id,protein_id)
                               values (?,?)"); 
     $sth->execute($conserved_segment->dbID,$prot_id);
   }

   return $conserved_segment->dbID;
}


1;
