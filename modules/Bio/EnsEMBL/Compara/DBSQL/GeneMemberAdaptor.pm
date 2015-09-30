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
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
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


=head2 load_all_from_seq_members

 Arg [1]    : arrayref of Bio::EnsEMBL::Compara::SeqMember
 Example    : $genemember_adaptor->load_all_from_seq_members($gene_tree->get_all_Members);
 Description: fetch the gene members for all the SeqMembers, and attach the former to the latter
 Returntype : none
 Caller     : general

=cut

sub load_all_from_seq_members {
    my $self = shift;
    my $seq_members = shift;

    my %by_gene_member_id = ();
    foreach my $seq_member (@$seq_members) {
        push @{$by_gene_member_id{$seq_member->gene_member_id}}, $seq_member;
    }
    my $all_gm = $self->fetch_all_by_dbID_list([keys %by_gene_member_id]);
    foreach my $gm (@$all_gm) {
        $_->gene_member($gm) for @{$by_gene_member_id{$gm->dbID}};
    }
}


=head2 fetch_by_Gene

  Arg[1]      : Bio::EnsEMBL::Gene $gene
  Arg[2]      : (opt) boolean: $verbose
  Example     : my $gene_member = $genemember_adaptor->fetch_by_Gene($gene);
  Description : Returns the GeneMember equivalent of the given Gene object.
                If $verbose is switched on and the gene is not in Compara, prints a warning.
  Returntype  : Bio::EnsEMBL::Compara::GeneMember
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_by_Gene {
    my ($self, $gene, $verbose) = @_;

    assert_ref($gene, 'Bio::EnsEMBL::Gene', 'gene');
    my $gene_member = $self->fetch_by_stable_id($gene->stable_id);
    warn $gene->stable_id." does not exist in the Compara database\n" if $verbose and not $gene_member;
    return $gene_member;
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
          'm.dnafrag_id',
          'm.dnafrag_start',
          'm.dnafrag_end',
          'm.dnafrag_strand',
          'm.canonical_member_id',
          'm.display_label',
          'm.families',
          'm.gene_trees',
          'm.gene_gain_loss_trees',
          'm.orthologues',
          'm.paralogues',
          'm.homoeologues',
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
		dnafrag_id      => $rowhash->{dnafrag_id},
		dnafrag_start   => $rowhash->{dnafrag_start},
		dnafrag_end     => $rowhash->{dnafrag_end},
		dnafrag_strand  => $rowhash->{dnafrag_strand},
		_source_name    => $rowhash->{source_name},
		_display_label  => $rowhash->{display_label},
            _canonical_member_id => $rowhash->{canonical_member_id},
            _num_families      => $rowhash->{families},
            _has_genetree   => $rowhash->{gene_trees},
            _has_genegainlosstree  => $rowhash->{gene_gain_loss_trees},
            _num_orthologues    => $rowhash->{orthologues},
            _num_paralogues     => $rowhash->{paralogues},
            _num_homoeologues   => $rowhash->{homoeologues},
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
  $member->dnafrag_id($rowhash->{'dnafrag_id'});
  $member->dnafrag_start($rowhash->{'dnafrag_start'});
  $member->dnafrag_end( $rowhash->{'dnafrag_end'});
  $member->dnafrag_strand($rowhash->{'dnafrag_strand'});
  $member->source_name($rowhash->{'source_name'});
  $member->display_label($rowhash->{'display_label'});
  $member->canonical_member_id($rowhash->{canonical_member_id});
  $member->number_of_families($rowhash->{families});
  $member->number_of_orthologues($rowhash->{orthologues});
  $member->number_of_paralogues($rowhash->{paralogues});
  $member->number_of_homoeologues($rowhash->{homoeologues});
  $member->has_GeneTree($rowhash->{gene_trees});
  $member->has_GeneGainLossTree($rowhash->{gene_gain_loss_trees});
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
                              dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand, display_label)
                            VALUES (?,?,?,?,?,?,?,?,?,?,?,?)");

  my $insertCount = $sth->execute($member->stable_id,
                  $member->version,
                  $member->source_name,
                  $member->canonical_member_id,
                  $member->taxon_id,
                  $member->genome_db_id,
                  $member->description,
                  $member->dnafrag_id,
                  $member->dnafrag_start,
                  $member->dnafrag_end,
                  $member->dnafrag_strand,
                  $member->display_label);
  if($insertCount>0) {
    #sucessful insert
    $member->dbID( $self->dbc->db_handle->last_insert_id(undef, undef, 'gene_member', 'gene_member_id') );
    $sth->finish;
  } else {
    $sth->finish;
    #UNIQUE(stable_id) prevented insert since gene_member was already inserted
    #so get gene_member_id with select
    my $sth2 = $self->prepare("SELECT gene_member_id, genome_db_id FROM gene_member WHERE stable_id=?");
    $sth2->execute($member->stable_id);
    my($id, $genome_db_id) = $sth2->fetchrow_array();
    warn("GeneMemberAdaptor: insert failed, but gene_member_id select failed too") unless($id);
    throw(sprintf('%s already exists and belongs to a different species (%s) ! Stable IDs must be unique across the whole set of species', $member->stable_id, $self->db->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id)->name )) if $genome_db_id and $member->genome_db_id and $genome_db_id != $member->genome_db_id;
    $member->dbID($id);
    $sth2->finish;
  }

  $member->adaptor($self);

  return $member->dbID;

}


1;

