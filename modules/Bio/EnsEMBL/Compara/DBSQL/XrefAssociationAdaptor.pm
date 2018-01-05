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

Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor

=head1 DESCRIPTION

This adaptor allows the storage and retrieval of the assoications between gene tree members and annotations such as InterPro and GO

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor
  `- Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::XrefAssociationAdaptor;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref);
use Bio::EnsEMBL::Registry;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');

my $insert_member_base_sql = q/insert into member_xref(gene_member_id,dbprimary_acc,external_db_id)/;

my $insert_member_sql = $insert_member_base_sql. q/ select gene_member_id,?,? from gene_member where stable_id=? and source_name='ENSEMBLGENE'/;
 
my $get_member_id_sql = q/select gene_member_id from gene_member where stable_id=? and source_name='ENSEMBLGENE'/;

my $delete_member_sql = q/delete mx.* from member_xref mx, gene_member m, genome_db g
where g.name=? and mx.external_db_id=?
and g.genome_db_id=m.genome_db_id and m.gene_member_id=mx.gene_member_id/;

my $base_get_sql = q/
select distinct g.stable_id,x.dbprimary_acc
from CORE.xref x
join CORE.external_db db using (external_db_id)
join CORE.object_xref ox using (xref_id)
GENE_JOIN join CORE.seq_region s on (g.seq_region_id=s.seq_region_id) 
join CORE.coord_system c using (coord_system_id)  
where db.db_name=? and c.species_id=?/;

my $translation_join = q/join CORE.translation t on (t.translation_id=ox.ensembl_id and ox.ensembl_object_type='Translation')
join CORE.transcript tc using (transcript_id)
join CORE.gene g using (gene_id)/;

my $transcript_join = q/join CORE.transcript tc on (tc.transcript_id=ox.ensembl_id and ox.ensembl_object_type='Transcript')
join CORE.gene g using (gene_id)/;

my $gene_join =
q/join CORE.gene g on (g.gene_id=ox.ensembl_id and ox.ensembl_object_type='Gene')/;

my $get_associations_direct = q/
select dbprimary_acc,count(*) as cnt from gene_tree_root r  
join gene_tree_node n using (root_id)  
join seq_member m using (seq_member_id)  
join member_xref mg on (m.gene_member_id=mg.gene_member_id)
join external_db e using (external_db_id)  
where r.root_id=? and e.db_name=?
group by dbprimary_acc,db_name order by cnt desc, dbprimary_acc asc
/;

my $get_members_for_xref = q/
select m.gene_member_id from member_xref mg 
join gene_member m  on (m.gene_member_id=mg.gene_member_id) 
join seq_member mp on (mp.gene_member_id=m.gene_member_id) 
join gene_tree_node gn on (gn.seq_member_id=mp.seq_member_id) 
join gene_tree_root r using (root_id) 
join external_db e using (external_db_id)
where mg.dbprimary_acc=? and e.db_name=? and r.root_id=?;
/;

my $get_member_xrefs_for_tree = q/
select mg.dbprimary_acc as acc, mg.gene_member_id 
from gene_tree_root r 
join gene_tree_node n using (root_id) 
join seq_member m on (m.seq_member_id=n.seq_member_id) 
join member_xref mg on (m.gene_member_id=mg.gene_member_id) 
join external_db e using (external_db_id)
where r.root_id=? and e.db_name=? order by acc
/;

my $get_external_db_id = q/select external_db_id from external_db where db_name=?/;

=head2 store_member_associations

  Arg[1]     : Core database adaptor 
  Arg[2]     : External database name
  Arg[3]     : Optional callback that generates a hash of gene stable ID to external database accession
  Example    : $adaptor->store_member_associations($dba, 'GO');

  Description: Method to retrieve external database accessions for genes in the supplied core and store them in the compara database
  Returntype : None
  Exceptions :
  Caller     :

=cut

sub store_member_associations {
	my ( $self, $dba, $db_name, $callback ) = @_;
	
	my $external_db_id = $self->dbc()->sql_helper()->execute_single_result(-SQL=>$get_external_db_id, -PARAMS=>[$db_name]);

	if(!defined $external_db_id) {
		throw "compara external_db entry not found for $db_name";
	}
	
	$callback ||= sub {
		my ( $compara, $core, $db_name ) = @_;
		my $member_acc_hash;
		for my $join_query ( $translation_join, $transcript_join, $gene_join ) {
			my $sql = $base_get_sql;
			$sql =~ s/GENE_JOIN/$join_query/;
			$sql =~ s/CORE.//g;
			$core->dbc()->sql_helper()->execute_no_return(
				-SQL          => $sql,
				-CALLBACK     => sub {
					my @row = @{ shift @_ };
					push @{ $member_acc_hash->{ $row[0] } }, $row[1];
					return;
				},
				-PARAMS => [$db_name,$core->species_id()] );
		}
		return $member_acc_hash;
	};
	my $member_acc_hash = $callback->( $self, $dba, $db_name );
	
	$self->dbc()->sql_helper()->execute_update(-SQL=>$delete_member_sql, -PARAMS=>[$dba->species(),$external_db_id]);
	
	while(my ($sid,$accs) = each %$member_acc_hash) {
		my ($gene_member_id) = @{$self->dbc()->sql_helper()->execute_simple(-SQL=>$get_member_id_sql, -PARAMS=>[$sid])};	
		if(defined $gene_member_id) {	
			my @pars = map {"($gene_member_id,\"$_\",$external_db_id)"} uniq(@$accs);
			my $sql = $insert_member_base_sql . 'values' . join(',',@pars);
			$self->dbc()->sql_helper()->execute_update(-SQL=>$sql, -PARAMS=>[]);
		}
	}
	return;
}

sub uniq {
    return keys %{{ map { $_ => 1 } @_ }};
}

=head2 get_associated_xrefs_for_tree

  Arg[1]     : Gene tree object or dbID
  Arg[2]     : External database name
  Example    : $adaptor->get_associated_xrefs_for_tree($tree,'GO');

  Description : Retrieve hash of associated dbprimary_accs and numbers of members for the supplied tree and database
  Returntype : Hashref of accessions to counts
  Exceptions :
  Caller     :

=cut

sub get_associated_xrefs_for_tree {
	my ( $self, $gene_tree, $db_name ) = @_;
	if ( check_ref( $gene_tree, 'Bio::EnsEMBL::Compara::GeneTree' ) ) {
		$gene_tree = $gene_tree->root_id();
	}
	return
	  $self->dbc()->sql_helper()->execute_simple(
											 -SQL => $get_associations_direct,
											 -PARAMS => [ $gene_tree, $db_name ]
	  );
}


=head2 get_members_for_xref

  Arg[1]     : Gene tree object or dbID
  Arg[2]     : Primary accession
  Arg[3]     : External database name
  Example    : $adaptor->get_associated_xrefs_for_tree_from_summary($tree,'GO:123456','GO');

  Description : Retrieve members for the supplied tree, primary acc and database. 
  Returntype : Arrayref of members
  Exceptions :
  Caller     :

=cut

sub get_members_for_xref {
	my ( $self, $gene_tree, $dbprimary_acc, $db_name ) = @_;
	if ( check_ref( $gene_tree, 'Bio::EnsEMBL::Compara::GeneTree' ) ) {
		$gene_tree = $gene_tree->root_id();
	}
	my $gene_member_ids = 
		$self->dbc()->sql_helper()->execute_simple(
							 -SQL    => $get_members_for_xref,
							 -PARAMS => [ $dbprimary_acc, $db_name, $gene_tree ]
		);

	my $gene_members = [];
	if ( scalar(@$gene_member_ids) > 0 ) {
		$gene_members = $self->_gene_member_adaptor()->fetch_all_by_dbID_list($gene_member_ids);
	}
	return $gene_members;
}

=head2 get_all_member_associations

  Arg[1]     : Gene tree object or dbID
  Arg[2]     : Primary accession
  Arg[3]     : External database name
  Example    : $adaptor->get_associated_xrefs_for_tree_from_summary($tree,'GO:123456','GO');

  Description : Retrieve gene_members and xref associations for the supplied tree, primary acc and database. 
  Returntype : Hashref containing database accessions as keys and arrayrefs of gene_members as keys 
  Exceptions :
  Caller     :

=cut

sub get_all_member_associations {
	my ( $self, $gene_tree, $db_name ) = @_;
	if ( check_ref( $gene_tree, 'Bio::EnsEMBL::Compara::GeneTree' ) ) {
		$gene_tree = $gene_tree->root_id();
	}
	my $assocs = {};
	$self->dbc()->sql_helper()->execute_no_return(
		-SQL      => $get_member_xrefs_for_tree,
		-PARAMS   => [ $gene_tree, $db_name ],
		-CALLBACK => sub {
			my ($row) = @_;
			push @{ $assocs->{ $row->[0] } }, $row->[1];
			return;
		} );
	while ( my ( $x, $ms ) = each %$assocs ) {
		$assocs->{$x} = $self->_gene_member_adaptor()->fetch_all_by_dbID_list($ms);
	}
	return $assocs;
}

sub _gene_member_adaptor {
	my ($self) = @_;
	if ( !defined $self->{_gene_member_adaptor} ) {
		$self->{_gene_member_adaptor} = $self->db->get_GeneMemberAdaptor();
	}
	return $self->{_gene_member_adaptor};
}

1;

