=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::GeneMember

=head1 DESCRIPTION

Class to represent a member that is a gene.
Genes do not have any sequences attached (see SeqMember for that purpose).

For each gene, we define a "canonical" or "representative" SeqMember, that
will be used in the gene-tree pipelines and the homologies.
This definition is purely internal and is not related to the biological importance
of that gene product.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneMember
  `- Bio::EnsEMBL::Compara::Member

=head1 SYNOPSIS

Member properties:
 - gene_member_id() is an alias for dbID()

Links with the Ensembl Core objects:
 - get_Gene()

Links with other Ensembl Compara Member objects:
 - get_canonical_SeqMember() and canonical_member_id()
 - get_all_SeqMembers()

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::GeneMember;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::Scalar qw(:all);

use base ('Bio::EnsEMBL::Compara::Member');



=head2 new_from_Gene

  Arg [-GENE] : Bio::Ensembl:Gene
  Arg [-GENOME_DB] : Bio::Ensembl:Compara:GenomeDB 
  Example    : $member = Bio::EnsEMBL::Compara::GeneMember->new_from_Gene(
                -gene   => $gene,
                -genome_db => $genome_db);
  Description: contructor method which takes an Ensembl::Gene object
               and Compara:GenomeDB object and creates a new GeneMember object
               translating from the Gene object
  Returntype : Bio::Ensembl::Compara::GeneMember
  Exceptions : undefined arguments, missing $gene->stable_id
  Caller     : general

=cut

sub new_from_Gene {
    my ($class, @args) = @_;

    my ($gene, $genome_db, $dnafrag, $biotype_group) = rearrange([qw(GENE GENOME_DB DNAFRAG BIOTYPE_GROUP)], @args);

    assert_ref($gene, 'Bio::EnsEMBL::Gene', 'gene');
    assert_ref($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');
    unless (defined $gene->stable_id) {
      throw("COREDB error: does not contain gene_stable_id for gene_id ". $gene->dbID."\n");
    }

    my $gene_member = Bio::EnsEMBL::Compara::GeneMember->new_fast({
        _stable_id => $gene->stable_id,
        _version => $gene->version,
        _display_label => ($gene->display_xref ? $gene->display_xref->display_id : undef),
        dnafrag_start => $gene->seq_region_start,
        dnafrag_end => $gene->seq_region_end,
        dnafrag_strand => $gene->seq_region_strand,
        dnafrag => $dnafrag || $genome_db->adaptor->db->get_DnaFragAdaptor->fetch_by_GenomeDB_and_name($genome_db, $gene->seq_region_name),
        _genome_db => $genome_db,
        _genome_db_id => $genome_db->dbID,
        _biotype_group => $biotype_group,
        _taxon_id => $genome_db->taxon_id,

        _source_name => 'ENSEMBLGENE',
        _description => $gene->description,
        core_gene => $gene,
    });
    return $gene_member;
}


=head2 gene_member_id

  Arg [1]    : (opt) integer
  Description: alias for dbID()

=cut

sub gene_member_id {
  my $self = shift;
  return $self->dbID(@_);
}


=head2 biotype_group

  Example     : my $biotype_group = $gene_member->biotype_group();
  Example     : $gene_member->biotype_group('snoncoding');
  Description : Getter/Setter for the biotype_group attribute.
  Returntype  : String
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub biotype_group {
    my $self = shift;
    $self->{'_biotype_group'} = shift if @_;
    return $self->{'_biotype_group'};
}


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

    my $able_adaptor = UNIVERSAL::can($self->adaptor, 'fetch_canonical_for_gene_member_id')
        ? $self->adaptor    # a MemberAdaptor or derivative
        : $self->adaptor->db->get_SeqMemberAdaptor;

        return $able_adaptor->fetch_canonical_for_gene_member_id($self->dbID);
}



=head2 canonical_member_id

  Arg [1]    : (opt) integer
  Returntype : Getter/Setter for the canonical_member_id

=cut

sub canonical_member_id {
  my $self = shift;
  $self->{'_canonical_member_id'} = shift if(@_);
  return $self->{'_canonical_member_id'};
}



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

    my $able_adaptor = UNIVERSAL::can($self->adaptor, 'fetch_all_by_GeneMember')
        ? $self->adaptor    # a MemberAdaptor or derivative
        : $self->adaptor->db->get_SeqMemberAdaptor;


    return $able_adaptor->fetch_all_by_GeneMember($self);
}


#
# Homology statistics
######################

sub _get_stat {
    my ($self, $collection, $stat_name) = @_;
    $collection = lc ($collection // 'default');
    $self->{'_stats'} //= {};
    unless ($self->{'_stats'}->{$collection}) {
        $self->{'_stats'} = $self->adaptor->db->dbc->db_handle->selectall_hashref('SELECT * FROM gene_member_hom_stats WHERE gene_member_id = ?', 'collection', undef, $self->dbID);
    }
    return $self->{'_stats'}->{$collection}->{$stat_name};
}

sub number_of_families {
    my ($self, $collection) = @_;
    return $self->_get_stat($collection, 'families');
}

sub has_GeneTree {
    my ($self, $collection) = @_;
    return $self->_get_stat($collection, 'gene_trees');
}

sub has_GeneGainLossTree {
    my ($self, $collection) = @_;
    return $self->_get_stat($collection, 'gene_gain_loss_trees');
}

sub number_of_orthologues {
    my ($self, $collection) = @_;
    return $self->_get_stat($collection, 'orthologues');
}

sub number_of_paralogues {
    my ($self, $collection) = @_;
    return $self->_get_stat($collection, 'paralogues');
}

sub number_of_homoeologues {
    my ($self, $collection) = @_;
    return $self->_get_stat($collection, 'homoeologues');
}

1;
