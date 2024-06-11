=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies

=head1 DESCRIPTION

When we build the strains/breeds/cultivars gene trees we end up with two databases,
both having some shared homology MLSSs (e.g. rat vs mouse). The redundant homology MLSSs
and their corresponding tags/attributes in the strains/breeds/cultivars database have to
be removed.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $master_dba          = $self->get_cached_compara_dba('master_db');
    my $master_mlss_adaptor = $master_dba->get_MethodLinkSpeciesSetAdaptor;
    my $master_ss_adaptor   = $master_dba->get_SpeciesSetAdaptor;

    my $ref_collection_list;
    if ( $self->param_is_defined('ref_collection') && $self->param_is_defined('ref_collection_list') ) {
        $self->throw("Only one of parameters 'ref_collection' or 'ref_collection_list' can be defined")
    } elsif ( $self->param_is_defined('ref_collection') ) {
        $ref_collection_list = [$self->param('ref_collection')];
    } elsif ( $self->param_is_defined('ref_collection_list') ) {
        $ref_collection_list = destringify($self->param('ref_collection_list'));
    } else {
        $self->throw("One of parameters 'ref_collection' or 'ref_collection_list' must be defined")
    }

    my %ref_mlss_by_id;
    foreach my $ref_collection_name (@{ $ref_collection_list }) {
        my $ref_collection = $master_ss_adaptor->fetch_collection_by_name($ref_collection_name);
        die "Cannot find collection '$ref_collection_name' in master_db" unless $ref_collection;
        foreach my $ml ( qw(ENSEMBL_ORTHOLOGUES ENSEMBL_PARALOGUES ENSEMBL_HOMOEOLOGUES) ) {
            foreach my $gdb1 ( @{ $ref_collection->genome_dbs } ) {
                foreach my $gdb2 ( @{ $ref_collection->genome_dbs } ) {
                    my $mlss = $master_mlss_adaptor->fetch_by_method_link_type_GenomeDBs($ml, [$gdb1, $gdb2]);
                    next unless defined $mlss and $mlss->is_current;
                    $ref_mlss_by_id{$mlss->dbID} = $mlss;
                }
            }
        }
    }
    my @ref_mlsses = values %ref_mlss_by_id;

    my $mlss_adaptor        = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my @overlapping_mlsss   = grep {$mlss_adaptor->fetch_by_dbID($_->dbID)} @ref_mlsses;

    $self->param('overlapping_mlsss', \@overlapping_mlsss);
}

sub run {
    my $self = shift;

    foreach my $mlss (@{$self->param('overlapping_mlsss')}) {
        warn "Going to remove ", $mlss->toString, "\n" if $self->debug;
        $self->_remove_homologies($mlss->dbID);
    }
}

sub _remove_homologies {
    my ($self, $mlss_id) = @_;

    $self->compara_dba->dbc->do('DELETE homology_member FROM homology_member JOIN homology USING (homology_id) WHERE method_link_species_set_id = ?', undef, $mlss_id);
    $self->compara_dba->dbc->do('DELETE FROM homology WHERE method_link_species_set_id = ?',                                                          undef, $mlss_id);
    $self->compara_dba->dbc->do('DELETE FROM method_link_species_set_tag WHERE method_link_species_set_id = ?',                                       undef, $mlss_id);
    $self->compara_dba->dbc->do('DELETE FROM method_link_species_set_attr WHERE method_link_species_set_id = ?',                                      undef, $mlss_id);
}

1;
