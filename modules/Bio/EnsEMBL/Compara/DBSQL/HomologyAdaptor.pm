package Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;
use vars qw(@ISA);
use strict;
use Bio::Root::Object;
use DBI;
use Bio::EnsEMBL::DBSQL::BaseAdaptor;
use Bio::EnsEMBL::Compara::Homology;
@ISA = qw(Bio::EnsEMBL::DBSQL::BaseAdaptor);





=head2 get_homologues_by_species_gene

 Title   : get_homologues_by_species_gene
 Usage   : $db->get_homologues_by_species_gene('Homo_sapiens','ENSG00000218116','Mus_musculus')
 Function: finds homologues of a given transcript
 Example :
 Returns : array of transcript stable ids
 Args    : species, transcript stable name, homologous species

=cut

sub get_homologues_by_species_gene  {

    my ($self,$species,$gene,$hspecies)=@_;

    my $q = "select grm.gene_relationship_id 
             from gene_relationship_member grm, gene_relationship gr, genome_db gd 
             where gd.genome_db_id=grm.genome_db_id and gr.gene_relationship_id=grm.gene_relationship_id 
             and gd.name='$species' and grm.member_stable_id='$gene' group by grm.gene_relationship_id";


    my @relationshipids = $self->_get_relationships($q);

    my @genes;
    foreach my $rel (@relationshipids) {
      push @genes, $self->_get_homologues_by_relationship_internal_ids($hspecies,$rel);
    }

    return @genes;

}                               


=head2 list_stable_ids_from_species

 Title   : list_stable_ids_from_species
 Usage   : $db->list_stable_ids_from_species('Homo_sapiens')
 Function: Find all the stable ids in the gene_relationship_member table 
           from a specified species 
 Example :
 Returns : array from transcript stable ids
 Args    : species

=cut

sub list_stable_ids_from_species  {

    my ($self,$species)=@_;

    my $q ="select grm.member_stable_id 
            from gene_relationship_member grm,genome_db gd 
            where gd.genome_db_id=grm.genome_db_id and gd.name='$species'";

    
    my @genes;

    my $sth = $self->prepare($q);
    $sth->execute();

    my $id;
    while (($id) = $sth->fetchrow_array) {
      push (@genes,$id);
    }

    return @genes;
}                               


sub _get_homologues_by_relationship_internal_ids{
    my ($self,$hspecies,$internal_id)=@_;

    my $q ="select grm.member_stable_id,grm.chrom_start,grm.chrom_end,grm.chromosome  
            from gene_relationship_member grm,genome_db gd 
            where gd.genome_db_id=grm.genome_db_id and gd.name='$hspecies' 
            and grm.gene_relationship_id=$internal_id";


    my @genes=$self->_get_homologues($q);

}

sub _get_homologues {
    my ($self,$q)=@_;

    $q = $self->prepare($q);
    $q->execute();

    my @genes;
    my $id;
    while (my $ref = $q->fetchrow_hashref) {
	my $homol= Bio::EnsEMBL::Compara::Homology->new();
	$homol->stable_id($ref->{'member_stable_id'});
	$homol->chrom_start($ref->{'chrom_start'});
        $homol->chrom_end($ref->{'chrom_end'});
        $homol->chromosome($ref->{'chromosome'});

	push (@genes,$homol);
    }
    return @genes;
   
}


sub _get_relationships {
    my ($self,$q)=@_;

    $q = $self->prepare($q);
    $q->execute();

    my @ids;
    my $id;
    while (($id) = $q->fetchrow_array) {
      push (@ids,$id);
    }
    return @ids;
}


sub _get_relationship {
    my ($self,$q)=@_;
    $q = $self->prepare($q);
    $q->execute();

    my @arr= $q->fetchrow_array;
    return $arr[0];

}


