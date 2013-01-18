package Bio::EnsEMBL::Compara::GeneMember;

use strict;
use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::Member');



=head2 new_from_gene

  Args       : Requires both an Bio::Ensembl:Gene object and a
             : Bio::Ensembl:Compara:GenomeDB object
  Example    : $member = Bio::EnsEMBL::Compara::GeneMember->new_from_gene(
                -gene   => $gene,
                -genome_db => $genome_db);
  Description: contructor method which takes an Ensembl::Gene object
               and Compara:GenomeDB object and creates a new GeneMember object
               translating from the Gene object
  Returntype : Bio::Ensembl::Compara::GeneMember
  Exceptions :
  Caller     :

=cut

sub new_from_gene {
  my ($class, @args) = @_;
  my $self = $class->new(@args);

  if (scalar @args) {

    my ($gene, $genome_db) = rearrange([qw(GENE GENOME_DB)], @args);

    unless(defined($gene) and $gene->isa('Bio::EnsEMBL::Gene')) {
      throw(
      "gene arg must be a [Bio::EnsEMBL::Gene] ".
      "not a [$gene]");
    }
    unless(defined($genome_db) and $genome_db->isa('Bio::EnsEMBL::Compara::GenomeDB')) {
      throw(
      "genome_db arg must be a [Bio::EnsEMBL::Compara::GenomeDB] ".
      "not a [$genome_db]");
    }
    unless (defined $gene->stable_id) {
      throw("COREDB error: does not contain gene_stable_id for gene_id ". $gene->dbID."\n");
    }

    $self->stable_id($gene->stable_id);
    $self->taxon_id($genome_db->taxon_id);
    $self->description($gene->description);
    $self->genome_db_id($genome_db->dbID);
    $self->chr_name($gene->seq_region_name);
    $self->chr_start($gene->seq_region_start);
    $self->chr_end($gene->seq_region_end);
    $self->chr_strand($gene->seq_region_strand);
    $self->source_name("ENSEMBLGENE");
  }
  return $self;
}



### SECTION 3 ###
#
# Global methods
###################









































### SECTION 4 ###
#
# Sequence methods
#####################


























### SECTION 5 ###
#
# print a member
##################








### SECTION 6 ###
#
# connection to core
#####################





=head2 get_Gene

  Args       : none
  Example    : $gene = $member->get_Gene
  Description: if member is an 'ENSEMBLGENE' returns Bio::EnsEMBL::Gene object
               by connecting to ensembl genome core database
               REQUIRES properly setup Registry conf file or
               manually setting genome_db->db_adaptor for each genome.
  Returntype : Bio::EnsEMBL::Gene or undef
  Exceptions : none
  Caller     : general

=cut

sub get_Gene {
  my $self = shift;
  
  return $self->{'core_gene'} if($self->{'core_gene'});
  
  unless($self->genome_db and 
         $self->genome_db->db_adaptor and
         $self->genome_db->db_adaptor->isa('Bio::EnsEMBL::DBSQL::DBAdaptor')) 
  {
    throw("unable to connect to core ensembl database: missing registry and genome_db.locator");
  }

  my $coreDBA = $self->genome_db->db_adaptor;
  if($self->source_name eq 'ENSEMBLGENE') {    
    $self->{'core_gene'} = $coreDBA->get_GeneAdaptor->fetch_by_stable_id($self->stable_id);
  } else {
    warn "get_Gene() is not implemented for ".$self->source_name
  }
  return $self->{'core_gene'};
}









### SECTION 7 ###
#
# canonical transcripts
########################



=head2 get_canonical_SeqMember

  Args       : none
  Example    : $canonicalMember = $member->get_canonical_SeqMember
  Description: returns the canonical peptide / transcript for that gene
  Returntype : Bio::EnsEMBL::Compara::SeqMember or undef
  Exceptions : throw if there is no adaptor
  Caller     : general

=cut

sub get_canonical_SeqMember {
    my $self = shift;

    return unless($self->adaptor);

    my $able_adaptor = UNIVERSAL::can($self->adaptor, 'fetch_canonical_member_for_gene_member_id')
        ? $self->adaptor    # a MemberAdaptor or derivative
        : $self->adaptor->db->get_MemberAdaptor;

        return $able_adaptor->fetch_canonical_member_for_gene_member_id($self->dbID);
}




### SECTION 8 ###
#
# sequence links
####################




=head2 get_all_SeqMembers

  Args       : none
  Example    : $pepMembers = $gene_member->get_all_SeqMembers
  Description: return listref of all sequence members  of this gene member
  Returntype : array ref of Bio::EnsEMBL::Compara::SeqMember
  Exceptions : throw if there is no adaptor
  Caller     : general

=cut

sub get_all_SeqMembers {
    my $self = shift;

    throw("adaptor undefined, cannot access database") unless($self->adaptor);

    my $able_adaptor = UNIVERSAL::can($self->adaptor, 'fetch_all_by_gene_member_id')
        ? $self->adaptor    # a MemberAdaptor or derivative
        : $self->adaptor->db->get_SeqMemberAdaptor;


    return $able_adaptor->fetch_all_by_gene_member_id($self->dbID);
}





### SECTION 9 ###
#
# WRAPPERS
###########







1;
