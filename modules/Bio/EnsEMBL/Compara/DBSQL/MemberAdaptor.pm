=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Base adaptor for Member objects that cannot be instantiated directly

The methods are still available for compatibility until release 74 (included),
but the Member object should not be explicitely used.

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
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions : throws if $stable_id is undef
  Caller     : 

=cut

sub fetch_by_stable_id {
    my ($self, $stable_id) = @_;

    throw("MemberAdaptor::fetch_by_stable_id() must have an stable_id") unless $stable_id;

    my $constraint = 'm.stable_id = ?';
    $self->bind_param_generic_fetch($stable_id, SQL_VARCHAR);
    return $self->generic_fetch_one($constraint);
}


=head2 fetch_by_source_stable_id

  Description: DEPRECATED: fetch_by_source_stable_id() is deprecated and will be removed in e84. Use fetch_by_stable_id() instead

=cut

sub fetch_by_source_stable_id {  ## DEPRECATED
    my ($self, $source_name, $stable_id) = @_;
    deprecate('MemberAdaptor::fetch_by_source_stable_id() is deprecated and will be removed in e84. Use fetch_by_stable_id() instead');
    my $member = $self->fetch_by_stable_id($stable_id);
    return undef unless $member;
    die "The member '$stable_id' has a different source_name than '$source_name': ".$member->source_name if $source_name and $source_name ne $member->source_name;
    return $member;
}


=head2 fetch_all_by_stable_id_list

  Arg [1]    : arrayref of string $stable_id
  Example    : my $members = $ma->fetch_all_by_stable_id_list(["O93279", "O62806"]);
  Description: Fetches the members corresponding to all the $stable_id.
  Returntype : arrayref Bio::EnsEMBL::Compara::Member object
  Caller     : 

=cut

sub fetch_all_by_stable_id_list {
    my ($self, $stable_ids) = @_;

    throw('MemberAdaptor::fetch_all_by_stable_id_list() must have a list of stable_ids') if (not ref $stable_ids) or (ref $stable_ids ne 'ARRAY');

    return [] if (!$stable_ids or !@$stable_ids);
    my $constraint = sprintf('m.stable_id IN ("%s")', join(q{","}, @$stable_ids));
    return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_source_stable_ids

  Description: DEPRECATED: fetch_all_by_source_stable_ids() is deprecated and will be removed in e84. Use fetch_all_by_stable_id_list() instead

=cut

sub fetch_all_by_source_stable_ids {  ## DEPRECATED
    my ($self, $source_name, $stable_ids) = @_;
    deprecate('MemberAdaptor::fetch_all_by_source_stable_ids() is deprecated and will be removed in e84. Use fetch_all_by_stable_id_list() instead');
    my $members = $self->fetch_all_by_stable_id_list($stable_ids);
    die "In fetch_all_by_source_stable_ids(), some of the members do not have the required source_name" if $source_name and grep {$_->source_name ne $source_name} @$stable_ids;
    return $members;
}



=head2 fetch_all

  Arg        : None
  Example    : my $members = $ma->fetch_all;
  Description: Fetch all the members in the db
               WARNING: Depending on the database where this method is called,
                        it can return a lot of data (objects) that has to be kept in memory.
                        Make sure you don't ask for more data than you can handle.
                        To access this data in a safer way, use fetch_all_Iterator instead.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : 
  Caller     : 

=cut

sub fetch_all {
  my $self = shift;

  return $self->generic_fetch();
}


=head2 fetch_all_Iterator

  Arg        : (optional) int $cache_size
  Example    : my $memberIter = $memberAdaptor->fetch_all_Iterator();
               while (my $member = $memberIter->next) {
                  #do something with $member
               }
  Description: Returns an iterator over all the members in the database
               This is safer than fetch_all for large databases.
  Returntype : Bio::EnsEMBL::Utils::Iterator
  Exceptions : 
  Caller     : 
  Status     : Experimental

=cut

sub fetch_all_Iterator {
    my ($self, $cache_size) = @_;
    return $self->generic_fetch_Iterator($cache_size,"");
}


=head2 fetch_all_by_source_Iterator

  Arg[1]     : string $source_name
  Arg[2]     : (optional) int $cache_size
  Example    : my $memberIter = $memberAdaptor->fetch_all_by_source_Iterator("ENSEMBLGENE");
               while (my $member = $memberIter->next) {
                  #do something with $member
               }
  Description: Returns an iterator over all the members corresponding
               to a source_name in the database.
               This is safer than fetch_all_by_source for large databases.
  Returntype : Bio::EnsEMBL::Utils::Iterator
  Exceptions : 
  Caller     : 
  Status     : Experimental

=cut

sub fetch_all_by_source_Iterator {
    my ($self, $source_name, $cache_size) = @_;
    throw("source_name arg is required\n") unless ($source_name);
    return $self->generic_fetch_Iterator($cache_size, "source_name = '$source_name'");
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
                To access this data in a safer way, use fetch_all_by_source_Iterator instead.
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


=head2 fetch_all_by_source_genome_db_id

  Description: DEPRECATED: fetch_all_by_source_genome_db_id() is deprecated and will be removed in e84. Use fetch_all_by_GenomeDB() instead

=cut

sub fetch_all_by_source_genome_db_id {  ## DEPRECATED
    my ($self, $source_name, $genome_db_id) = @_;
    deprecate('fetch_all_by_source_genome_db_id() is deprecated and will be removed in e84. Use fetch_all_by_GenomeDB() instead');
    return $self->fetch_all_by_GenomeDB($genome_db_id, $source_name);
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


#TODO fetch_all_by_Slice($slice)
#TODO fetch_all_by_Locus($locus, -expand_both, -expand_5, -expand_3, -limit

sub _fetch_all_by_dnafrag_id_start_end_strand_limit {
  my ($self,$dnafrag_id,$dnafrag_start,$dnafrag_end,$dnafrag_strand,$limit) = @_;

  $self->throw("all args are required")
      unless($dnafrag_start && $dnafrag_end && $dnafrag_strand && defined ($dnafrag_id));

  my $constraint = '(m.dnafrag_id = ?) AND (m.dnafrag_start BETWEEN ? AND ?) AND (m.dnafrag_end BETWEEN ? AND ?) AND (m.dnafrag_strand = ?)';
  $self->bind_param_generic_fetch($dnafrag_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_start, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_end, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_start, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_end, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_strand, SQL_INTEGER);

  return $self->generic_fetch($constraint, undef, defined $limit ? "LIMIT $limit" : "");
}


=head2 fetch_all_by_dnafrag_id_start_end

  Arg [1]    : dnafrag db ID
  Arg [2]    : int Start - the start position of the region you want
  Arg [3]    : int End - the end position of the region you want
  Example    : my $genemembers_arrayref = $memberDBA->fetch_all_by_dnafrag_id_start_end($dnafragID, $start, $end);
  Description: Returns a arrayref of the list of gene members spanning the given region on the given dnafrag
  Returntype : Array ref
  Exceptions : undefined arguments

=cut
sub fetch_all_by_dnafrag_id_start_end {

  my ($self,$dnafrag_id,$dnafrag_start,$dnafrag_end) = @_;
    $self->throw("all args are required")
      unless($dnafrag_start && $dnafrag_end && defined ($dnafrag_id));

  my $constraint = '(m.dnafrag_id = ?) AND (m.dnafrag_start BETWEEN ? AND ?) AND (m.dnafrag_end BETWEEN ? AND ?)';
  $self->bind_param_generic_fetch($dnafrag_id, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_start, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_end, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_start, SQL_INTEGER);
  $self->bind_param_generic_fetch($dnafrag_end, SQL_INTEGER);
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

    my @tabs = $self->_tables;
  my $sth = $self->prepare
    ("SELECT COUNT(*) FROM $tabs[0][0] WHERE source_name=? AND taxon_id=?");
  $sth->execute($source_name, $taxon_id);
  my ($count) = $sth->fetchrow_array();
  $sth->finish;

  return $count;
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
    assert_ref($set, 'Bio::EnsEMBL::Compara::MemberSet');
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

