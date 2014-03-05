=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor

=head1 DESCRIPTION

Adaptor to retrieve GeneMember objects.
Most of the methods are shared with the SeqMemberAdaptor.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut


package Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor;

use strict; 
use warnings;

use Bio::EnsEMBL::Compara::GeneMember;

use Bio::EnsEMBL::Utils::Scalar qw(:all);
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning stack_trace_dump);
use DBI qw(:sql_types);

use base qw(Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor);


=head2 fetch_all_homology_orphans_by_GenomeDB

 Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
 Example    : $GenomeDBAdaptor->fetch_all_homology_orphans_by_GenomeDB($genome_db);
 Description: fetch the members for a genome_db that have no homologs in the database
 Returntype : an array reference of Bio::EnsEMBL::Compara::Member objects
 Exceptions : when isa if Arg [1] is not Bio::EnsEMBL::Compara::GenomeDB
 Caller     : general

=cut

sub fetch_all_homology_orphans_by_GenomeDB {
  my $self = shift;
  my $gdb = shift;

  assert_ref($gdb, 'Bio::EnsEMBL::Compara::GenomeDB');

  my $constraint = 'm.genome_db_id = ?';
  $self->bind_param_generic_fetch($gdb->dbID, SQL_INTEGER);

  # The LEFT JOIN condition is actually below and therefore shared by all the fetch methods
  # To activate it, a fetch has to alias "homology_member" into "left_homology"
  my $join = [[['homology_member', 'left_homology'], 'left_homology.gene_member_id IS NULL']];

  return $self->generic_fetch($constraint, $join);
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



#
# INTERNAL METHODS
#
###################

sub _left_join {
    return (
        ['homology_member left_homology', 'left_homology.gene_member_id = m.gene_member_id'],
    );
}


sub _tables {
  return (['gene_member', 'm']);
}

sub _columns {
  return ('m.gene_member_id',
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
          'm.canonical_member_id',
          'm.display_label'
          );
}

sub create_instance_from_rowhash {
	my ($self, $rowhash) = @_;
	
	return Bio::EnsEMBL::Compara::GeneMember->new_fast({
		adaptor         => $self,
		dbID            => $rowhash->{gene_member_id},
		_stable_id      => $rowhash->{stable_id},
		_version        => $rowhash->{version},
		_taxon_id       => $rowhash->{taxon_id},
		_genome_db_id   => $rowhash->{genome_db_id},
		_description    => $rowhash->{description},
		_chr_name       => $rowhash->{chr_name},
		dnafrag_start   => $rowhash->{chr_start} || 0,
		dnafrag_end     => $rowhash->{chr_end} || 0,
		dnafrag_strand  => $rowhash->{chr_strand} || 0,
		_source_name    => $rowhash->{source_name},
		_display_label  => $rowhash->{display_label},
            _canonical_member_id => $rowhash->{canonical_member_id},
	});
}

sub init_instance_from_rowhash {
  my $self = shift;
  my $member = shift;
  my $rowhash = shift;

  $member->gene_member_id($rowhash->{'gene_member_id'});
  $member->stable_id($rowhash->{'stable_id'});
  $member->version($rowhash->{'version'});
  $member->taxon_id($rowhash->{'taxon_id'});
  $member->genome_db_id($rowhash->{'genome_db_id'});
  $member->description($rowhash->{'description'});
  $member->chr_name( $rowhash->{'chr_name'} );
  $member->dnafrag_start($rowhash->{'chr_start'} || 0 );
  $member->dnafrag_end( $rowhash->{'chr_end'} || 0 );
  $member->dnafrag_strand($rowhash->{'chr_strand'} || 0 );
  $member->source_name($rowhash->{'source_name'});
  $member->display_label($rowhash->{'display_label'});
  $member->canonical_member_id($rowhash->{canonical_member_id}) if $member->can('canonical_member_id');
  $member->adaptor($self) if ref $self;

  return $member;
}



#
# STORE METHODS
#
################


sub store {
    my ($self, $member) = @_;
   
    assert_ref($member, 'Bio::EnsEMBL::Compara::GeneMember');


  my $sth = $self->prepare("INSERT ignore INTO gene_member (stable_id,version, source_name,
                              canonical_member_id,
                              taxon_id, genome_db_id, description,
                              chr_name, chr_start, chr_end, chr_strand,display_label)
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");

  my $insertCount = $sth->execute($member->stable_id,
                  $member->version,
                  $member->source_name,
                  $member->canonical_member_id,
                  $member->taxon_id,
                  $member->genome_db_id,
                  $member->description,
                  $member->chr_name,
                  $member->chr_start,
                  $member->chr_end,
                  $member->chr_strand,
                  $member->display_label);
  if($insertCount>0) {
    #sucessful insert
    $member->dbID( $sth->{'mysql_insertid'} );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(source_name,stable_id) prevented insert since member was already inserted
    #so get gene_member_id with select
    my $sth2 = $self->prepare("SELECT gene_member_id FROM gene_member WHERE source_name=? and stable_id=?");
    $sth2->execute($member->source_name, $member->stable_id);
    my($id) = $sth2->fetchrow_array();
    warn("MemberAdaptor: insert failed, but gene_member_id select failed too") unless($id);
    $member->dbID($id);
    $sth2->finish;
  }

  $member->adaptor($self);

  return $member->dbID;

}


1;

