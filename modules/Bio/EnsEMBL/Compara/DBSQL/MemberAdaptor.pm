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

Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor

=head1 DESCRIPTION

Base adaptor for Member objects.  This adaptor cannot be used directly.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use strict; 
use warnings;

use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate);

use Bio::EnsEMBL::Compara::Utils::Scalar qw(:assert);

use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);




#
# GLOBAL METHODS
#
#####################


=head2 fetch_by_stable_id

  Arg [1]    : string $stable_id
  Example    : my $member = $ma->fetch_by_stable_id("O93279");
  Description: Fetches the member corresponding to this $stable_id.
               This method accepts versionned stable IDs, such as ENSG00000157764.12
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions : throws if $stable_id is undef
  Caller     : 

=cut

sub fetch_by_stable_id {
    my ($self, $stable_id) = @_;

    throw("MemberAdaptor::fetch_by_stable_id() must have an stable_id") unless $stable_id;

    my $constraint = 'm.stable_id = ?';
    $self->bind_param_generic_fetch($stable_id, SQL_VARCHAR);
    my $m = $self->generic_fetch_one($constraint);
    return $m if $m;

    my $vindex = rindex($stable_id, '.');
    return undef if $vindex <= 0;  # bail out if there is no dot, or if the string starts with a dot (since that would make the stable_id part empty)
    my $version = substr($stable_id,$vindex+1);
    if (looks_like_number($version)) {  # to avoid DBI complains
        $constraint = 'm.stable_id = ? AND m.version = ?';
        $self->bind_param_generic_fetch(substr($stable_id,0,$vindex), SQL_VARCHAR);
        $self->bind_param_generic_fetch($version, SQL_INTEGER);
        return $self->generic_fetch_one($constraint);
    } else {
        return undef;
    }
}


=head2 fetch_all_by_stable_id_list

  Arg [1]    : arrayref of string $stable_id
  Example    : my $members = $ma->fetch_all_by_stable_id_list(["O93279", "O62806"]);
  Description: Fetches the members corresponding to all the $stable_id.
               This method des *not* accept versionned stable IDs (e.g. ENSG00000157764.12)
  Returntype : arrayref Bio::EnsEMBL::Compara::Member object
  Caller     : 

=cut

sub fetch_all_by_stable_id_list {
    my ($self, $stable_ids) = @_;

    # Core's method does all the type-checks for us
    return $self->SUPER::_uncached_fetch_all_by_id_list($stable_ids, undef, 'stable_id', 0);
}


=head2 fetch_all_by_source

  Arg [1]    : string $source_name
  Example    : my $members = $ma->fetch_all_by_source(
                   "Uniprot/SWISSPROT");
  Description: Fetches the member corresponding to a source_name.
                WARNING: Depending on the database and the "source"
                where this method is called, it can return a lot of data (objects)
                that has to be kept in memory. Make sure you don't ask
                for more data than you can handle.
                To access this data in a safer way, use generic_fetch_Iterator instead.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $source_name is undef
  Caller     :

=cut

sub fetch_all_by_source {
  my ($self,$source_name) = @_;

  throw("source_name arg is required\n")
    unless ($source_name);

  my $constraint = 'm.source_name = ?';
  $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);

  return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_source_taxon

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : my $members = $ma->fetch_all_by_source_taxon(
                   "Uniprot/SWISSPROT", 9606);
  Description: Fetches the member corresponding to a source_name and a taxon_id.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $source_name or $taxon_id is undef
  Caller     : 

=cut

sub fetch_all_by_source_taxon {
  my ($self,$source_name,$taxon_id) = @_;

  throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND m.taxon_id = ?');
}


=head2 fetch_all_by_GenomeDB

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg [2]    : string $source_name (optional)
  Example    : my $members = $ma->fetch_all_by_GenomeDB($genome_db);
  Description: Fetches the member corresponding to a GenomeDB (and possibly a source_name)
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $genome_db has an incorrect type
  Caller     : 

=cut

sub fetch_all_by_GenomeDB {
    my ($self, $genome_db, $source_name) = @_;

    assert_ref_or_dbID($genome_db, 'Bio::EnsEMBL::Compara::GenomeDB', 'genome_db');

    my $constraint = 'm.genome_db_id = ?';
    $self->bind_param_generic_fetch(ref($genome_db) ? $genome_db->dbID : $genome_db, SQL_INTEGER);

    if ($source_name) {
        $constraint .= ' AND m.source_name = ?';
        $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    }

    return $self->generic_fetch($constraint);
}


sub _count_all_by_dnafrag_id_start_end_strand {
  my ($self,$dnafrag_id,$dnafrag_start,$dnafrag_end,$dnafrag_strand) = @_;

  $self->throw("all args are required")
      unless($dnafrag_start && $dnafrag_end && $dnafrag_strand && defined ($dnafrag_id));

  my $constraint = '(m.dnafrag_id = ?) AND (m.dnafrag_start BETWEEN ? AND ?) AND (m.dnafrag_end BETWEEN ? AND ?) AND (m.dnafrag_strand = ?)';
  $self->bind_param_generic_fetch($dnafrag_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_start, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_end, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_start, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_end, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_strand, SQL_INTEGER);

  return $self->generic_count($constraint);
}


=head2 fetch_all_by_Slice

  Arg[1]      : Bio::EnsEMBL::Slice $slice
  Arguments   : See L<fetch_all_by_Locus> for a description of the optional arguments
  Example     : $gene_member_adaptor->fetch_all_by_Slice($slice, -FULLY_WITHIN => 1);
  Description : Fetches all the members for the given L<Bio::EnsEMBL::Slice>. Use the parameter
                FULLY_WITHIN to return the members *overlapping* or *contained* in this slice.
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::Member (or derived classes)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_Slice {
    my $self = shift;
    my $slice = shift;
    my $dnafrag = $self->db->get_DnaFragAdaptor->fetch_by_Slice($slice);
    throw "Could not find find a DnaFrag for ".$slice->name unless $dnafrag;
    my $locus = Bio::EnsEMBL::Compara::Locus->new_fast( {
            'dnafrag_id'        => $dnafrag->dbID,
            'dnafrag_start'     => $slice->start,
            'dnafrag_end'       => $slice->end,
            'dnafrag_strand'    => $slice->strand,
        });
    return $self->fetch_all_by_Locus($locus, @_);
}


=head2 fetch_all_by_Locus

  Arg[1]      : Bio::EnsEMBL::Compara::Locus $locus. An instance of a derived class like GenomicAlign works
  Arg [-FULLY_WITHIN] (opt) Boolean
              : By default, the method returns all the members that overlap the Locus. Set this
                parameter to True to return the members that are fully inside the Locus.
  Arg [-EXPAND_5] (opt) Integer (default: 0)
              : Number of base-pairs to extend the given Locus on its 5' end (which is its dnafrag *end* when on the negative strand)
  Arg [-EXPAND_3] (opt) Integer (default: 0)
              : Number of base-pairs to extend the given Locus on its 3' end (which is its dnafrag *start* when on the negative strand)
  Example     : $gene_member_adaptor->fetch_all_by_Locus($genomic_align);
  Description : Fetches all the members for the given L<Bio::EnsEMBL::Compara::Locus> which is the base
                class for many objects including L<Bio::EnsEMBL::Compara::GenomicAlign>, L<Bio::EnsEMBL::Compara::DnaFragRegion>
                and L<Bio::EnsEMBL::Compara::Member>
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::Member (or derived classes)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_Locus {
    my ($self, $locus, @args) = @_;
    assert_ref($locus, 'Bio::EnsEMBL::Compara::Locus', 'locus');

    my ($fully_within, $expand_5, $expand_3) = rearrange([qw(FULLY_WITHIN EXPAND_5 EXPAND_3)], @args);

    my $start = $locus->dnafrag_start - ($locus->dnafrag_strand > 0 ? $expand_5 : $expand_3);
    my $end   = $locus->dnafrag_end   + ($locus->dnafrag_strand > 0 ? $expand_3 : $expand_5);

    if ($fully_within) {
        my $constraint = '(m.dnafrag_id = ?) AND (m.dnafrag_start BETWEEN ? AND ?) AND (m.dnafrag_end BETWEEN ? AND ?)';
        $self->bind_param_generic_fetch($locus->dnafrag_id, SQL_INTEGER);
        $self->bind_param_generic_fetch($start, SQL_INTEGER);
        $self->bind_param_generic_fetch($end, SQL_INTEGER);
        $self->bind_param_generic_fetch($start, SQL_INTEGER);
        $self->bind_param_generic_fetch($end, SQL_INTEGER);
        return $self->generic_fetch($constraint);
    } else {
        my $constraint = '(m.dnafrag_id = ?) AND (m.dnafrag_start <= ?) AND (m.dnafrag_end >= ?)';
        $self->bind_param_generic_fetch($locus->dnafrag_id, SQL_INTEGER);
        $self->bind_param_generic_fetch($end, SQL_INTEGER);
        $self->bind_param_generic_fetch($start, SQL_INTEGER);
        return $self->generic_fetch($constraint);
    }
}


=head2 fetch_all_by_DnaFrag

  Arg[1]      : Bio::EnsEMBL::Compara::DnaFrag $dnafrag
  Example     : $gene_member_adaptor->fetch_all_by_DnaFrag($chr3_dnafrag);
  Description : Fetches all the members that are on the given DnaFrag
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::Member (or derived classes)
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_DnaFrag {
    my ($self, $dnafrag) = @_;
    assert_ref($dnafrag, 'Bio::EnsEMBL::Compara::DnaFrag', 'dnafrag');

    my $constraint = '(m.dnafrag_id = ?)';
    $self->bind_param_generic_fetch($dnafrag->dbID, SQL_INTEGER);
    return $self->generic_fetch($constraint);
}


=head2 get_source_taxon_count

  Arg [1]    : string $source_name
  Arg [2]    : int $taxon_id
  Example    : my $sp_gene_count = $memberDBA->get_source_taxon_count('ENSEMBLGENE',$taxon_id);
  Description: Returns the number of members for this source_name and taxon_id
  Returntype : int
  Exceptions : undefined arguments

=cut

sub get_source_taxon_count {
  my ($self,$source_name,$taxon_id) = @_;

  throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
    return $self->generic_count('source_name=? AND taxon_id=?');
}



=head2 fetch_all_by_MemberSet

  Arg[1]     : MemberSet $set
               Currently supported: Family, Homology and GeneTree
  Example    : $family_members = $m_adaptor->fetch_all_by_MemberSet($family);
  Description: Fetches from the database all the members attached to this set
  Returntype : arrayref of Bio::EnsEMBL::Compara::Member
  Exceptions : argument not a MemberSet
  Caller     : general

=cut

sub fetch_all_by_MemberSet {
    my ($self, $set) = @_;
    assert_ref($set, 'Bio::EnsEMBL::Compara::MemberSet', 'set');
    if (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::AlignedMemberSet')) {
        return $self->db->get_AlignedMemberAdaptor->fetch_all_by_AlignedMemberSet($set);
    } else {
        throw("$self is not a recognized MemberSet object\n");
    }
}



#
# INTERNAL METHODS
#
###################


sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @members = ();

  while(my $rowhash = $sth->fetchrow_hashref) {
    my $member = $self->create_instance_from_rowhash($rowhash);
    push @members, $member;
  }
  $sth->finish;
  return \@members
}



1;

