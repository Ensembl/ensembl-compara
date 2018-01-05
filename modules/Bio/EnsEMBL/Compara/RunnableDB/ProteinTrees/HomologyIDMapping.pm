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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping

=cut

=head1 SYNOPSIS

Required inputs:
	- homology mlss_id
	- optionally a "previous_mlss_id"
	- URL pointing to the previous release database
	- pointer to current database (usually doesn't require explicit definition)

Example:
	standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping -mlss_id 20285 -compara_db mysql://ensro@compara5/cc21_protein_trees_no_reuse_86 -prev_rel_db mysql://ensro@compara2/mp14_protein_trees_85

=cut

=head1 DESCRIPTION

Homology ids can change from one release to the next. This runnable detects
the homology id from the previous release database based on the gene members
of the current homologies.

Data should be flowed out to a table to be queried later by pipelines aiming
to reuse homology data.

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyIDMapping;

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(:insert);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;

    my $mlss_id         = $self->param_required('mlss_id');
    my $mlss            = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
    my $prev_mlss_id    = $self->param('previous_mlss_id');

    if (defined $prev_mlss_id) {
        $self->_fetch_and_map_previous_homologies( $prev_mlss_id);
    } else {
        $self->param( 'homology_mapping', [] );
    }
}

sub _fetch_and_map_previous_homologies {
    my ($self, $previous_mlss_id) = @_;

    $self->compara_dba->dbc->disconnect_if_idle;

    my $previous_compara_dba    = $self->get_cached_compara_dba('prev_rel_db');
    my $previous_homologies     = $previous_compara_dba->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($previous_mlss_id);

    my $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($previous_compara_dba->get_AlignedMemberAdaptor, $previous_homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($previous_compara_dba->get_GeneMemberAdaptor, $sms);
    $previous_compara_dba->dbc->disconnect_if_idle;
    undef $sms;

    my %hash_previous_homologies;
    foreach my $prev_homology (@$previous_homologies) {
        my @gene_members = @{ $prev_homology->get_all_GeneMembers() };
        $hash_previous_homologies{$gene_members[0]->stable_id . '_' . $gene_members[1]->stable_id} = $prev_homology->dbID;
        $hash_previous_homologies{$gene_members[1]->stable_id . '_' . $gene_members[0]->stable_id} = $prev_homology->dbID;
    }
    undef $previous_homologies;

    my $mlss_id             = $self->param('mlss_id');
    my $current_homologies  = $self->compara_dba->get_HomologyAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss_id);
    $sms = Bio::EnsEMBL::Compara::Utils::Preloader::expand_Homologies($self->compara_dba->get_AlignedMemberAdaptor, $current_homologies);
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_GeneMembers($self->compara_dba->get_GeneMemberAdaptor, $sms);
    $self->compara_dba->dbc->disconnect_if_idle;

    my @homology_mapping;
    foreach my $curr_homology (@$current_homologies) {
        my @gene_members        = @{ $curr_homology->get_all_GeneMembers() };
        my $prev_homology_id    = $hash_previous_homologies{$gene_members[0]->stable_id . '_' . $gene_members[1]->stable_id};

        push( @homology_mapping, [$mlss_id, $prev_homology_id, $curr_homology->dbID] ) if $prev_homology_id;

    }

    $self->param( 'homology_mapping', \@homology_mapping );
}


sub write_output {
	my $self = shift;

	print "INSERTING" if $self->debug;
	print Dumper $self->param('homology_mapping') if $self->debug;
        bulk_insert($self->compara_dba->dbc, 'homology_id_mapping', $self->param('homology_mapping'), ['mlss_id', 'prev_release_homology_id', 'curr_release_homology_id'], 'INSERT IGNORE');
}

1;
