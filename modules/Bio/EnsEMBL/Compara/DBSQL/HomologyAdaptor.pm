package Bio::EnsEMBL::Compara::DBSQL::HomologyAdaptor;

use strict;
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor;

our @ISA = qw(Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor);

=head2 fetch_homologues_of_gene_in_species

 Title   : fetch_homologues_of_gene_in_species
 Usage   : $db->fetch_homologues_of_gene_in_species('Homo_sapiens','ENSG00000218116','Mus_musculus')
 Function: finds homologues, in a certain species, of a given gene
 Example :
 Returns : array of homology objects (Bio::EnsEMBL::Compara::Homology)
 Args    : species gene is from, gene stable name, species to find homology in

=cut

sub fetch_homologues_of_gene_in_species{

    my ($self,$species,$gene,$hspecies)=@_;

    $hspecies =~ tr/_/ /;
    $species  =~ tr/_/ /;

    my $q = "select grm.gene_relationship_id 
             from   gene_relationship_member grm, 
		    genome_db gd 
             where  gd.genome_db_id = grm.genome_db_id 
             and    gd.name = '$species' 
	     and    grm.member_stable_id = '$gene' 
	     group by grm.gene_relationship_id";

    my @relationshipids = $self->_get_relationships($q);

    my @genes;
    foreach my $rel (@relationshipids) {
      push @genes, $self->_fetch_homologues_by_species_relationship_id($hspecies,$rel);
    }

    return @genes;
}                               

=head2 fetch_by_relation

 Arg [1]    : string $dbname
 Arg [2]    : string $member_stable_id
 Example    : $fams = $FamilyAdaptor->fetch_of_dbname_id('SPTR', 'P01235');
 Description: find the family to which the given database and  member_stable_id belong
 Returntype : an array reference of Bio::EnsEMBL::Compara::Family objects
              (could be empty or contain more than one Family in the case of ENSEMBLGENE only)
 Exceptions : when missing arguments
 Caller     : general

=cut

sub fetch_by_Member {
  my ($self, $member) = @_;

  my $join = [['homology_member', 'hm'], 'h.homology_id = hm.homology_id'];
  my $constraint = "hm.member_id = " .$member->dbID;;

  return $self->generic_fetch($constraint, $join);
}

sub fetch_by_Member_source {
  my ($self, $member, $source_name) = @_;

  unless ($member->isa('Bio::EnsEMBL::Compara::Member')) {
    $self->throw("The argument must be a Bio::EnsEMBL::Compara::Member object, not $member");
  }

  $self->throw("source_name arg is required\n")
    unless ($source_name);
  
  my $join = [['homology_member', 'hm'], 'h.homology_id = hm.homology_id'];
  my $constraint = "s.source_name = $source_name";
  $constraint .= " AND hm.member_id = " . $member->dbID;

  return $self->generic_fetch($constraint, $join);
}

=head2 fetch_homologues_of_gene

 Title   : fetch_homologues_of_gene
 Usage   : $db->fetch_homologues_of_gene('Homo_sapiens','ENSG00000218116')
 Function: finds homologues of a given gene
 Example :
 Returns : an array of homology objects
 Args    : species gene is from, gene stable name

=cut

sub fetch_homologues_of_gene {

    my ($self,$species,$gene)=@_;

    $species  =~ tr/_/ /;

    my $q = "select grm.gene_relationship_id 
             from   gene_relationship_member grm, 
		    genome_db gd 
             where  gd.genome_db_id = grm.genome_db_id 
             and    gd.name = '$species' 
	     and    grm.member_stable_id = '$gene' 
	     group by grm.gene_relationship_id";

    my @relationshipids = $self->_get_relationships($q);

    my @genes;
    foreach my $rel (@relationshipids) {
	my $q ="select  grm.member_stable_id,
			gd.name,
                        grm.chromosome,
                        grm.chrom_start,
                        grm.chrom_end
		from    gene_relationship_member grm,
			genome_db gd
		where   grm.gene_relationship_id = $rel 
		and	grm.genome_db_id = gd.genome_db_id 
		and NOT	(grm.member_stable_id = '$gene')";

	push @genes,$self->_get_homologues($q); 
    }

    return @genes;
}                               


=head2 fetch_homologues_by_chr_start_in_species

 Title   : fetch_homologues_by_chr_start_in_species
 Usage   : $db->fetch_homologues_by_chr_start_in_species(   'Homo_sapiens',
							    'X',
							    1000,
							    'Mus_musculus', 
							    10)
	Will return 10 human genes in order from 1000bp on chrX along with 10 homologues from mouse.  If no homologue, homologue will be "no known homologue"
 Function: finds a list of homologues with a given species
 Example :
 Returns : a hash of species names against arrays of homology objects
 Args    : species from, chr, start, second spp, number of homologues to fetch

=cut

sub fetch_homologues_by_chr_start_in_species {
    my ($self, $species, $chr, $start, $hspecies, $num)=@_;

    $hspecies =~ tr/_/ /;
    $species =~ tr/_/ /;

    my $q = "select grm.gene_relationship_id 
             from   gene_relationship_member grm, 
		    genome_db gd 
             where  gd.genome_db_id = grm.genome_db_id 
             and    gd.name = '$species' 
	     and    grm.chromosome = '$chr'
	     and    grm.chrom_start >= $start
	     group by grm.gene_relationship_id
	     order by grm.chrom_start
	     limit $num";

    my @relationshipids = $self->_get_relationships($q);

    my %genes;
    foreach my $rel (@relationshipids) {
      push @{$genes{$species}}, $self->_fetch_homologues_by_species_relationship_id($species, $rel);
      push @{$genes{$hspecies}}, $self->_fetch_homologues_by_species_relationship_id($hspecies, $rel);
    
    }

    return %genes;
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

    $species =~ tr/_/ /;

    my $q ="select  grm.member_stable_id 
            from    gene_relationship_member grm,
		    genome_db gd 
            where   gd.genome_db_id = grm.genome_db_id 
	    and	    gd.name = '$species'";

    my @genes;

    my $sth = $self->prepare($q);
    $sth->execute();

    my $id;
    while (($id) = $sth->fetchrow_array) {
      push (@genes,$id);
    }

    return @genes;
}                               


sub _fetch_homologues_by_species_relationship_id{
    my ($self,$hspecies,$internal_id)=@_;

    my $q ="select  grm.member_stable_id,
		    gd.name,
                    grm.chromosome,
                    grm.chrom_start,
                    grm.chrom_end
            from    gene_relationship_member grm,
		    genome_db gd 
            where   gd.genome_db_id = grm.genome_db_id 
	    and	    gd.name = '$hspecies' 
            and	    grm.gene_relationship_id = $internal_id";

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
	$homol->species($ref->{'name'});
	$homol->stable_id($ref->{'member_stable_id'});
	$homol->chromosome($ref->{'chromosome'});
	$homol->chrom_start($ref->{'chrom_start'});
	$homol->chrom_end($ref->{'chrom_end'});
	
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

1;
