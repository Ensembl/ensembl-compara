=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor

=head1 DESCRIPTION

Base adaptor for Member objects. This adaptor is deprecated: SeqMemberAdaptor
and GeneMemberAdaptor are supposed to be used to fetch Members.

The methods are still available for compatibility until release 74 (included),
but the Member object should not be explicitely used.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Compara::Member;

use Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor;
use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning stack_trace_dump deprecate);
use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor);








#
# GLOBAL METHODS
#
#####################


=head2 fetch_by_source_stable_id

  Arg [1]    : (optional) string $source_name
  Arg [2]    : string $stable_id
  Example    : my $member = $ma->fetch_by_source_stable_id(
                   "Uniprot/SWISSPROT", "O93279");
  Example    : my $member = $ma->fetch_by_source_stable_id(
                   undef, "O93279");
  Description: Fetches the member corresponding to this $stable_id.
               Although two members from different sources might
               have the same stable_id, this never happens in a normal
               compara DB. You can set the first argument to undef
               like in the second example.
  Returntype : Bio::EnsEMBL::Compara::Member object
  Exceptions : throws if $stable_id is undef
  Caller     : 

=cut

sub fetch_by_source_stable_id {
  my ($self,$source_name, $stable_id) = @_;

  $self->_warning_member_adaptor();
  unless(defined $stable_id) {
    throw("fetch_by_source_stable_id must have an stable_id");
  }

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = '';
  if ($source_name) {
    $constraint = 'm.source_name = ? AND ';
    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
  }
  $constraint .= 'm.stable_id = ?';
  $self->bind_param_generic_fetch($stable_id, SQL_VARCHAR);

  return $self->generic_fetch_one($constraint);
}


=head2 fetch_all_by_source_stable_ids

  Arg [1]    : (optional) string $source_name
  Arg [2]    : arrayref of string $stable_id
  Example    : my $members = $ma->fetch_by_source_stable_id(
                   "Uniprot/SWISSPROT", ["O93279", "O62806"]);
  Description: Fetches the members corresponding to all the $stable_id.
  Returntype : arrayref Bio::EnsEMBL::Compara::Member object
  Caller     : 

=cut

sub fetch_all_by_source_stable_ids {
  my ($self,$source_name, $stable_ids) = @_;
  $self->_warning_member_adaptor();
  return [] if (!$stable_ids or !@$stable_ids);

  #construct a constraint like 't1.table1_id = 1'
  my $constraint = "";
  $constraint = "m.source_name = '$source_name' AND " if ($source_name);
  $constraint .= "m.stable_id IN ('".join("','", @$stable_ids). "')";

  #return first element of generic_fetch list
  my $obj = $self->generic_fetch($constraint);
  return $obj;
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

  $self->_warning_member_adaptor();
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
    $self->_warning_member_adaptor();
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
    $self->_warning_member_adaptor();
    throw("source_name arg is required\n") unless ($source_name);
    return $self->generic_fetch_Iterator($cache_size, "member.source_name = '$source_name'");
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

  $self->_warning_member_adaptor();
  throw("source_name arg is required\n")
    unless ($source_name);

  my $constraint = "m.source_name = '$source_name'";

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

    $self->_warning_member_adaptor();
  throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($taxon_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND m.taxon_id = ?');
}


=head2 fetch_all_by_source_genome_db_id

  Arg [1]    : string $source_name
  Arg [2]    : int $genome_db_id
  Example    : my $members = $ma->fetch_all_by_source_genome_db_id(
                   "Uniprot/SWISSPROT", 90);
  Description: Fetches the member corresponding to a source_name and a genome_db_id.
  Returntype : listref of Bio::EnsEMBL::Compara::Member objects
  Exceptions : throws if $source_name or $genome_db_id is undef
  Caller     : 

=cut

sub fetch_all_by_source_genome_db_id {
  my ($self,$source_name,$genome_db_id) = @_;

    $self->_warning_member_adaptor();
  throw("source_name and genome_db_id args are required") 
    unless($source_name && $genome_db_id);

    $self->bind_param_generic_fetch($source_name, SQL_VARCHAR);
    $self->bind_param_generic_fetch($genome_db_id, SQL_INTEGER);
    return $self->generic_fetch('m.source_name = ? AND m.genome_db_id = ?');
}


sub _fetch_all_by_source_taxon_chr_name_start_end_strand_limit {
  my ($self,$source_name,$taxon_id,$chr_name,$chr_start,$chr_end,$chr_strand,$limit) = @_;

  $self->_warning_member_adaptor();
  $self->throw("all args are required") 
      unless($source_name && $taxon_id && $chr_start && $chr_end && $chr_strand && defined ($chr_name));

  my $constraint = "m.source_name = '$source_name' and m.taxon_id = $taxon_id 
                    and m.chr_name = '$chr_name' 
                    and m.chr_start >= $chr_start and m.chr_start <= $chr_end and m.chr_end <= $chr_end 
                    and m.chr_strand = $chr_strand";

  return $self->generic_fetch($constraint, undef, defined $limit ? "LIMIT $limit" : "");
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

  $self->_warning_member_adaptor();
  throw("source_name and taxon_id args are required") 
    unless($source_name && $taxon_id);

  my $sth = $self->prepare
    ("SELECT COUNT(*) FROM member WHERE source_name=? AND taxon_id=?");
  $sth->execute($source_name, $taxon_id);
  my ($count) = $sth->fetchrow_array();
  $sth->finish;

  return $count;
}


=head2 fetch_all_by_Domain

  Arg [1]    : Bio::EnsEMBL::Compara::Domain $domain
  Status     : Experimental

=cut

sub fetch_all_by_Domain {
    my ($self, $domain) = @_;
    $self->_warning_member_adaptor();
    assert_ref($domain, 'Bio::EnsEMBL::Compara::Domain');

    my $domain_id = $domain->dbID;
    my $constraint = "dm.domain_id = $domain_id";
    my $extra_columns = [qw(dm.domain_id dm.member_start dm.member_end)];
    my $join = [[['domain_member', 'dm'], 'm.member_id = dm.member_id', $extra_columns]];

    return $self->generic_fetch($constraint, $join);
}


=head2 fetch_all_by_MemberSet

  Arg[1]     : MemberSet $set: Currently: Domain, Family, Homology and GeneTree
                are supported
  Example    : $family_members = $m_adaptor->fetch_all_by_MemberSet($family);
  Description: Fetches from the database all the members attached to this set
  Returntype : arrayref of Bio::EnsEMBL::Compara::Member
  Exceptions : argument not a MemberSet
  Caller     : general

=cut

sub fetch_all_by_MemberSet {
    my ($self, $set) = @_;
    $self->_warning_member_adaptor();
    assert_ref($set, 'Bio::EnsEMBL::Compara::MemberSet');
    if (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::AlignedMemberSet')) {
        return $self->db->get_AlignedMemberAdaptor->fetch_all_by_AlignedMemberSet($set);
    } elsif (UNIVERSAL::isa($set, 'Bio::EnsEMBL::Compara::Domain')) {
        return $self->fetch_all_by_Domain($set);
    } else {
        throw("$self is not a recognized MemberSet object\n");
    }
}





#
# SeqMember only methods
#
############################


=head2 fetch_all_by_sequence_id

  Description: DEPRECATED. Use SeqMemberAdaptor::fetch_all_by_sequence_id() instead

=cut

sub fetch_all_by_sequence_id { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('fetch_all_by_sequence_id', @_);
}





=head2 fetch_all_peptides_for_gene_member_id

  Description: DEPRECATED. Use SeqMemberAdaptor::fetch_all_by_gene_member_id() instead

=cut

sub fetch_all_peptides_for_gene_member_id { # DEPRECATED
    my $self = shift;

    return $self->_rename_method_seq('fetch_all_peptides_for_gene_member_id', 'fetch_all_by_gene_member_id', @_);
}




=head2 fetch_all_canonical_by_source_genome_db_id

  Description: DEPRECATED. Use SeqMemberAdaptor::fetch_all_canonical_by_source_genome_db_id() instead

=cut

sub fetch_all_canonical_by_source_genome_db_id { # DEPRECATED
    my $self = shift;

    return $self->_wrap_method_seq('fetch_all_canonical_by_source_genome_db_id', @_);
}






=head2 fetch_canonical_member_for_gene_member_id

  Description: DEPRECATED. Use SeqMemberAdaptor::fetch_canonical_for_gene_member_id() instead

=cut

sub fetch_canonical_member_for_gene_member_id { # DEPRECATED
    my $self = shift;

    return $self->_rename_method_seq('fetch_canonical_member_for_gene_member_id', 'fetch_canonical_for_gene_member_id', @_);
}







#
# GeneMember only methods
############################









#
# INTERNAL METHODS
#
###################

sub _tables {
  return (['member', 'm']);
}

sub _columns {
  return ('m.member_id',
          'm.source_name',
          'm.stable_id',
          'm.version',
          'm.taxon_id',
          'm.genome_db_id',
          'm.description',
          'm.chr_name',
          'm.chr_start',
          'm.chr_end',
          'm.chr_strand',
          'm.sequence_id',
          'm.gene_member_id',
          'm.canonical_member_id',
          'm.display_label'
          );
}

sub create_instance_from_rowhash {
	my ($self, $rowhash) = @_;
	
	return Bio::EnsEMBL::Compara::Member->new_fast({
		_adaptor        => $self,                   # field name NOT in sync with Bio::EnsEMBL::Storable
		_dbID           => $rowhash->{member_id},   # field name NOT in sync with Bio::EnsEMBL::Storable
		_stable_id      => $rowhash->{stable_id},
		_version        => $rowhash->{version},
		_taxon_id       => $rowhash->{taxon_id},
		_genome_db_id   => $rowhash->{genome_db_id},
		_description    => $rowhash->{description},
		_chr_name       => $rowhash->{chr_name},
		dnafrag_start   => $rowhash->{chr_start} || 0,
		dnafrag_end     => $rowhash->{chr_end} || 0,
		dnafrag_strand  => $rowhash->{chr_strand} || 0,
		_sequence_id    => $rowhash->{sequence_id} || 0,
		_source_name    => $rowhash->{source_name},
		_display_label  => $rowhash->{display_label},
		_gene_member_id => $rowhash->{gene_member_id},
            _canonical_member_id => $rowhash->{canonical_member_id},
	});
}

sub init_instance_from_rowhash {
  my $self = shift;
  my $member = shift;
  my $rowhash = shift;

  $member->member_id($rowhash->{'member_id'});
  $member->stable_id($rowhash->{'stable_id'});
  $member->version($rowhash->{'version'});
  $member->taxon_id($rowhash->{'taxon_id'});
  $member->genome_db_id($rowhash->{'genome_db_id'});
  $member->description($rowhash->{'description'});
  $member->chr_name( $rowhash->{'chr_name'} );
  $member->dnafrag_start($rowhash->{'chr_start'} || 0 );
  $member->dnafrag_end( $rowhash->{'chr_end'} || 0 );
  $member->dnafrag_strand($rowhash->{'chr_strand'} || 0 );
  $member->sequence_id($rowhash->{'sequence_id'});
  $member->gene_member_id($rowhash->{'gene_member_id'});
  $member->source_name($rowhash->{'source_name'});
  $member->display_label($rowhash->{'display_label'});
  $member->canonical_member_id($rowhash->{canonical_member_id}) if $member->can('canonical_member_id');
  $member->adaptor($self);

  return $member;
}

sub _objs_from_sth {
  my ($self, $sth) = @_;

  my @members = ();

  while(my $rowhash = $sth->fetchrow_hashref) {
    my $member = $self->create_instance_from_rowhash($rowhash);
    
    my @_columns = $self->_columns;
    if (scalar keys %{$rowhash} > scalar @_columns) {
      if (exists $rowhash->{domain_id}) {
        bless $member, 'Bio::EnsEMBL::Compara::MemberDomain';
        $member->member_start($rowhash->{member_start});
        $member->member_end($rowhash->{member_end});
      }
    }
    push @members, $member;
  }
  $sth->finish;
  return \@members
}


#
# STORE METHODS
#
################


sub store {
    my ($self, $member) = @_;
   
    $self->_warning_member_adaptor();
    assert_ref($member, 'Bio::EnsEMBL::Compara::Member');


  my $sth = $self->prepare("INSERT ignore INTO member (stable_id,version, source_name,
                              gene_member_id,
                              taxon_id, genome_db_id, description,
                              chr_name, chr_start, chr_end, chr_strand,display_label)
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");

  my $insertCount = $sth->execute($member->stable_id,
                  $member->version,
                  $member->source_name,
                  $member->isa('Bio::EnsEMBL::Compara::SeqMember') ? $member->gene_member_id : undef,
                  $member->taxon_id,
                  $member->genome_db_id,
                  $member->description,
                  $member->chr_name,
                  $member->dnafrag_start,
                  $member->dnafrag_end,
                  $member->dnafrag_strand,
                  $member->display_label);
  if($insertCount>0) {
    #sucessful insert
    $member->dbID( $sth->{'mysql_insertid'} );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(source_name,stable_id) prevented insert since member was already inserted
    #so get member_id with select
    my $sth2 = $self->prepare("SELECT member_id, sequence_id FROM member WHERE source_name=? and stable_id=?");
    $sth2->execute($member->source_name, $member->stable_id);
    my($id, $sequence_id) = $sth2->fetchrow_array();
    warn("MemberAdaptor: insert failed, but member_id select failed too") unless($id);
    $member->dbID($id);
    $member->sequence_id($sequence_id) if ($sequence_id) and $member->isa('Bio::EnsEMBL::Compara::SeqMember');
    $sth2->finish;
  }

  $member->adaptor($self);

  # insert in sequence table to generate new
  # sequence_id to insert into member table;
  if($member->isa('Bio::EnsEMBL::Compara::SeqMember') and defined($member->sequence) and $member->sequence_id == 0) {
    $member->sequence_id($self->db->get_SequenceAdaptor->store($member->sequence,1)); # Last parameter induces a check for redundancy

    my $sth3 = $self->prepare("UPDATE member SET sequence_id=? WHERE member_id=?");
    $sth3->execute($member->sequence_id, $member->dbID);
    $sth3->finish;
  }

  return $member->dbID;
}









sub update_sequence { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('update_sequence', @_);
}







sub _set_member_as_canonical { # DEPRECATED
    my $self = shift;
    return $self->_wrap_method_seq('_set_member_as_canonical', @_);
}












### SECTION 9 ###
#
# WRAPPERS
###########

no strict 'refs';

use Bio::EnsEMBL::ApiVersion;

sub _text_warning {
    my $msg = shift;
    return
        "\n------------------ DEPRECATED ---------------------\n"
        . "$msg\n"
        . stack_trace_dump(5). "\n"
        . "You are using the version ".software_version()." of the API. The old methods / objects are available for compatibility until version 74 (included)\n"
        . "---------------------------------------------------\n";
}


sub _warning_member_adaptor {
    my $self = shift;


    unless ($self->isa('Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor') or
            $self->isa('Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor')) {
        warn _text_warning(qq{
            The Member adaptor is deprecated in favour of the more specific GeneMember and SeqMember adaptors.
            Please update your code (change the adaptor) here:
        });
    }
}


sub _wrap_method_seq {
    my $self = shift;
    my $method = shift;
    warn _text_warning(qq{
        $method() should be called on the SeqMember adaptor (not on the Member or GeneMember adaptors).
        Please update your code (change the adaptor) here:
    });
    my $method_wrap = "Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor::$method";
    return $method_wrap->($self, @_);
}

sub _rename_method_seq {
    my $self = shift;
    my $method = shift;
    my $new_name = shift;
    warn _text_warning(qq{
        $method() is renamed to $new_name() and should be called on the SeqMember adaptor (not on the Member or GeneMember adaptors).
        Please update your code: change the adaptor, and use $new_name() instead:
    });
    my $method_wrap = "Bio::EnsEMBL::Compara::DBSQL::SeqMemberAdaptor::$new_name";
    return $method_wrap->($self, @_);
}




#
# RAW SQLs FOR WEBCODE
#
########################

sub families_for_member {
  my ($self, $stable_id) = @_;

  my $sql = 'SELECT families FROM member_production_counts WHERE stable_id = ?';
  my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id);
  return $res;
}

sub member_has_GeneTree {
  my ($self, $stable_id) = @_;

  my $sql = "SELECT gene_trees FROM member_production_counts WHERE stable_id = ?";
  my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id);
  return $res;
}

sub member_has_GeneGainLossTree {
  my ($self, $stable_id) = @_;

  my $sql = "SELECT gene_gain_loss_trees FROM member_production_counts WHERE stable_id = ?";
  my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id);
  return $res;
}

sub orthologues_for_member {
  my ($self, $stable_id) = @_;

  my $sql = "SELECT orthologues FROM member_production_counts WHERE stable_id = ?";
  my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id);
  return $res;
}

sub paralogues_for_member {
  my ($self, $stable_id) = @_;

  my $sql = "SELECT paralogues FROM member_production_counts WHERE stable_id = ?";
  my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id);
  return $res;
}


# sub member_has_family {
#     my ($self, $stable_id) = @_;

#     my $sql = 'select count(*) from family_member fm, member as m where fm.member_id=m.member_id and stable_id=? and source_name =?';
#     my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id, 'ENSEMBLGENE');
#     return $res;
# }
#
#
# sub homologies_for_member {
#     my ($self, $stable_id) = @_;

#     my $sql = "SELECT ml.type, h.description, count(*) AS N FROM member AS m, homology_member AS hm, homology AS h, method_link AS ml, method_link_species_set AS mlss WHERE m.stable_id = ? AND hm.member_id = m.member_id AND h.homology_id = hm.homology_id AND mlss.method_link_species_set_id = h.method_link_species_set_id AND ml.method_link_id = mlss.method_link_id GROUP BY description";
#     my $res = $self->dbc->db_handle()->selectall_arrayref($sql, {}, $stable_id);

#     my $counts = {};
#     foreach (@$res) {
#         if ($_->[0] eq 'ENSEMBL_PARALOGUES' && $_->[1] ne 'possible_ortholog') {
#             $counts->{'paralogs'} += $_->[2];
#         } elsif ($_->[1] !~ /^UBRH|BRH|MBRH|RHS$/) {
#             $counts->{'orthologs'} += $_->[2];
#         }
#     }

#     return $counts;
# }

# sub member_has_geneTree {
#     my ($self, $stable_id) = @_;

#     my $sql = 'SELECT COUNT(*) FROM gene_tree_node JOIN member mp USING (member_id) JOIN member mg ON mp.member_id = mg.canonical_member_id WHERE mg.stable_id = ? AND mg.source_name = ?';

#     my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id, 'ENSEMBLGENE');
#     return $res;
# }

# sub member_has_geneGainLossTree {
#     my ($self, $stable_id) = @_;

#     my $sql = 'SELECT count(*) FROM CAFE_gene_family cgf JOIN gene_tree_root gtr ON(cgf.gene_tree_root_id = gtr.root_id) JOIN gene_tree_node gtn ON(gtr.root_id = gtn.root_id) JOIN member mp USING (member_id) JOIN member mg ON (mp.member_id = mg.canonical_member_id) WHERE mg.stable_id = ? AND mg.source_name = ?';

#     my ($res) = $self->dbc->db_handle()->selectrow_array($sql, {}, $stable_id, 'ENSEMBLGENE');
# }


1;

