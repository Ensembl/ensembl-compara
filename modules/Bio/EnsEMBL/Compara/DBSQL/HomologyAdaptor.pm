package Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use vars qw(@ISA);
use strict;
use Bio::Root::Object;
use DBI;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;

@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);





=head2 get_homologues_by_species_transcript

 Title   : get_homologues_by_species_transcript
 Usage   : $db->get_homologues_by_species_gene('Homo_sapiens','ENST00000218116','Mus_musculus')
 Function: finds homologues of a given transcript
 Example :
 Returns : array of transcript stable ids
 Args    : species, transcript stable name, homologous species

=cut

sub get_homologues_by_species_transcript  {

    my ($self,$species,$gene,$hspecies)=@_;

    my $q = "select grm.gene_relationship_id 
             from gene_relationship_member grm, gene_relationship gr, genome_db gd 
             where gd.genome_db_id=grm.genome_db_id and gr.gene_relationship_id=grm.gene_relationship_id 
             and gd.name='$species' and grm.member_stable_id='$gene' group by grm.gene_relationship_id";

    my @transcripts=$self->_get_genes_by_relationship_internal_id($hspecies,$self->_get_relationship($q));



}                               


sub  _get_genes_by_relationship_internal_id {
    my ($self,$hspecies,$internal_id)=@_;

    my $q ="select grm.member_stable_id 
            from gene_relationship_member grm,genome_db gd 
            where gd.genome_db_id=grm.genome_db_id and gd.name='$hspecies' 
            and grm.gene_relationship_id=$internal_id";


    my @transcript=$self->_get_gene_stable_ids($q);

}




sub _get_gene_stable_ids {
    my ($self,$q)=@_;

    $q = $self->prepare($q);
    $q->execute();

    return $q->fetchrow_array;



}




sub _get_relationship {
    my ($self,$q)=@_;
    $q = $self->prepare($q);
    $q->execute();

    my @arr= $q->fetchrow_array;
    return $arr[0];

}


