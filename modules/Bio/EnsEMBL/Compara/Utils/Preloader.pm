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

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Preloader

=head1 DESCRIPTION

Most of the objects do lazy-loading of related objects via queries to the
database. This system is sub-optimal when there are a lot of objects to
fetch.

This module provides several methods to do a bulk-loading of objects in a
minimum number of queries.

NOTE: The subroutines declared here don't shift $self out of their parameters.
Run Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($dnafrag_adaptor, $gene_tree->get_all_leaves)

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::Utils::Preloader;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(wrap_array assert_ref check_ref);
use Bio::EnsEMBL::Utils::Exception qw(throw);


=head2 load_all_DnaFrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor $dnafrag_adaptor. The adaptor that is used to retrieve the objects.
  Arg[2..n]   : Objects or arrays
  Example     : load_all_DnaFrags($dnafrag_adaptor, $gene_tree->get_all_leaves);
  Description : Method to load the DnaFrags of many objects in a minimum number of queries.
                It assumes that the internal keys are 'dnafrag_id' and 'dnafrag', which is the case of:
                  DnaFragRegion, GeneMember, SeqMember, GeneTreeMember, GenomicAlign
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::DnaFrag : the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_all_DnaFrags {
    my $dnafrag_adaptor = shift;
    assert_ref($dnafrag_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::DnaFragAdaptor', 'dnafrag_adaptor');
    return _load_and_attach_all('dnafrag_id', 'dnafrag', $dnafrag_adaptor, @_);
}


=head2 load_all_NCBITaxon

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor $ncbitaxon_adaptor. The adaptor that is used to retrieve the objects.
  Arg[2..n]   : Objects or arrays
  Example     : load_all_NCBITaxon($ncbitaxon_adaptor, $gene_tree->get_all_leaves);
  Description : Method to load the NCBITaxons of many objects in a minimum number of queries.
                It assumes that the internal keys are '_taxon_id' and '_taxon', which is the case of:
                  SpeciesTreeNode, GenomeDB, GeneMember, SeqMember, GeneTreeMember
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::NCBITaxon : the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_all_NCBITaxon {
    my $ncbitaxon_adaptor = shift;
    assert_ref($ncbitaxon_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::NCBITaxonAdaptor', 'ncbitaxon_adaptor');
    my $all_taxa = _load_and_attach_all('_taxon_id', '_taxon', $ncbitaxon_adaptor, @_);
    $ncbitaxon_adaptor->_load_tagvalues_multiple($all_taxa);
    return $all_taxa
}


=head2 load_all_SpeciesTreeNodes

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor $stn_adaptor. The adaptor that is used to retrieve the objects.
  Arg[2..n]   : Objects or arrays
  Example     : load_all_SpeciesTreeNodes($stn_adaptor, $homologies);
  Description : Method to load the SpeciesTreeNodes of many objects in a minimum number of queries.
                It assumes that the internal keys are '_species_tree_node_id' and '_species_tree_node', which is the case of:
                  Homology
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::SpeciesTreeNode : the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_all_SpeciesTreeNodes {
    my $stn_adaptor = shift;
    assert_ref($stn_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::SpeciesTreeNodeAdaptor', 'stn_adaptor');
    return _load_and_attach_all('_species_tree_node_id', '_species_tree_node', $stn_adaptor, @_);
}


=head2 load_all_GeneMembers

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor $genemember_adaptor. The adaptor that is used to retrieve the objects.
  Arg[2..n]   : Objects or arrays
  Example     : load_all_GeneMembers($genemember_adaptor, $gene_tree->get_all_leaves);
  Description : Method to load the GeneMembers of many objects in a minimum number of queries.
                It assumes that the internal keys are 'dnafrag_id' and 'dnafrag', which is the case of:
                  SeqMember
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::GeneMember : the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_all_GeneMembers {
    my $genemember_adaptor = shift;
    assert_ref($genemember_adaptor, 'Bio::EnsEMBL::Compara::DBSQL::GeneMemberAdaptor', 'genemember_adaptor');
    return _load_and_attach_all('_gene_member_id', '_gene_member', $genemember_adaptor, @_);
}


=head2 _load_and_attach_all

  Arg[1]      : String $id_internal_key. Name of the key in the objects that contains the dbID of the objects to load
  Arg[2]      : String $object_internal_key. Name of the key in the objects to attach the new objects
  Arg[3]      : Bio::EnsEMBL::DBSQL::BaseAdaptor $adaptor. The adaptor that is used to retrieve the objects.
  Arg[4..n]   : Objects or arrays
  Example     : _load_and_attach_all('dnafrag_id', 'dnafrag', $dnafrag_adaptor, $gene_tree->get_all_leaves);
  Description : Generic method to fetch all the objects from the database in a minimum number of queries.
  Returntype  : Arrayref: the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub _load_and_attach_all {
    my ($id_internal_key, $object_internal_key, $adaptor, @args) = @_;

    my %key2iniobject = ();
    my %key2newobject = ();
    my %seen = ();
    foreach my $a (@args) {
        foreach my $o (@{wrap_array($a)}) {
            next if !ref($o);                   # We need a ref to an object
            next if ref($o) !~ /::/;            # but not one of the basic types
            next if !$o->{$id_internal_key};    # It needs to have the dbID key

            # Check if the target object has already been loaded
            if ($o->{$object_internal_key}) {
                $key2newobject{$o->{$id_internal_key}} = $o->{$object_internal_key};

            # Check if there are redundant objects in @args
            } elsif (!$seen{$o}) {
                push @{$key2iniobject{$o->{$id_internal_key}}}, $o;
                $seen{$o} = 1;
            }
        }
    }

    my @keys_to_fetch = grep {!$key2newobject{$_}} keys %key2iniobject;
    return [] unless scalar(@keys_to_fetch);
    my $all_new_objects = $adaptor->fetch_all_by_dbID_list(\@keys_to_fetch);
    foreach my $o (@$all_new_objects, values %key2newobject) {
        $_->{$object_internal_key} = $o for @{$key2iniobject{$o->dbID}};
    }
    return $all_new_objects;
}


=head2 load_all_sequences

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::SequenceAdaptor $sequence_adaptor. The adaptor that is used to retrieve the sequences
  Arg[2]      : (optional) $seq_type. Used to load the non-default sequences
  Arg[3..n]   : Objects or arrays. MemberSets are automatically expanded with get_all_Members()
  Example     : load_all_sequences($sequence_adaptor, 'cds', $gene_tree);
  Description : Method to load the sequences of many objects in a minimum number of queries.
                Works with SeqMember, AlignedMember, GeneTreeMember, Family, Homology, GeneTree
  Returntype  : Arrayref of strings: the sequences loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub load_all_sequences {
    my ($sequence_adaptor, $seq_type, @args) = @_;

    my $internal_sequence_key = $seq_type ? "_sequence_$seq_type" : '_sequence';
    my $internal_key_for_adaptor = $seq_type ? 'dbID' : '_sequence_id';

    my %key2member = ();
    foreach my $a (@args) {
      foreach my $aa (@{wrap_array($a)}) {
        my $members = check_ref($aa, 'Bio::EnsEMBL::Compara::MemberSet') ? $aa->get_all_Members : [$aa];
        foreach my $member (@$members) {
            next if !check_ref($member, 'Bio::EnsEMBL::Compara::SeqMember');    # Only works with SeqMember
            next if $member->{$internal_sequence_key};                          # ... that don't have a sequence yet
            next if !$member->{$internal_key_for_adaptor};                      # ... and have a sequence id
            push @{$key2member{$member->{$internal_key_for_adaptor}}}, $member;
        }
      }
    }
    my @all_keys = keys %key2member;
    return [] unless scalar(@all_keys);

    my $seqs = $seq_type ? $sequence_adaptor->fetch_other_sequences_by_member_ids_type(\@all_keys, $seq_type)
                         : $sequence_adaptor->fetch_all_by_dbID_list(\@all_keys);
    while (my ($id, $seq) = each %$seqs) {
        $_->{$internal_sequence_key} = $seq for @{$key2member{$id}};
    }
    return [values %$seqs];
}


=head2 expand_Homologies

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::AlignedMemberAdaptor $aligned_member_adaptor. The adaptor that is used to retrieve the objects.
  Arg[2..n]   : Objects or arrays
  Example     : expand_Homologies($aligned_member_adaptor, $homologies);
  Description : Method to load the SeqMembers of many Homologies in a minimum number of queries (for get_all_Members)
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::SeqMember : the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub expand_Homologies {
    my $aligned_member_adaptor = shift;

    my %homologies;
    foreach my $a (@_) {
        foreach my $o (@{wrap_array($a)}) {
            next if !check_ref($o, 'Bio::EnsEMBL::Compara::Homology');      # It has to be an Homology
            next if defined $o->{'_member_array'};                          # ... that doesn't have its members yet
            $homologies{$o->dbID} = $o;
        }
    }
    return [] unless %homologies;
    my $members = $aligned_member_adaptor->fetch_all_by_Homology(values %homologies);
    $homologies{$_->{'_member_of_homology_id'}}->add_Member($_) for @$members;
    return $members;
}


1;
