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

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies

=head1 DESCRIPTION

When we build the mouse-strains protein-trees we end up with two database
both having some homology MLSS (e.g. rat vs mouse).
We decide here to remove the redundant MLSSs and their homologies from the
dependent database.

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RemoveOverlappingHomologies;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $master_dba          = $self->get_cached_compara_dba('master_db');
    my $master_mlss_adaptor = $master_dba->get_MethodLinkSpeciesSetAdaptor;
    my $ref_collection_name = $self->param_required('ref_collection');
    my $ref_collection      = $master_dba->get_SpeciesSetAdaptor->fetch_collection_by_name($ref_collection_name);
    die "Cannot find collection '$ref_collection_name' in master_db" unless $ref_collection;
    my @ref_mlsses;
    foreach my $ml ( qw(ENSEMBL_ORTHOLOGUES ENSEMBL_PARALOGUES ENSEMBL_HOMOEOLOGUES) ) {
        foreach my $gdb1 ( @{ $ref_collection->genome_dbs } ) {
            foreach my $gdb2 ( @{ $ref_collection->genome_dbs } ) {
                my $mlss = $master_mlss_adaptor->fetch_by_method_link_type_GenomeDBs($ml, [$gdb1, $gdb2]);
                next unless $mlss->is_current;
                push @ref_mlsses, $mlss;
            }
        }
    }

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

}

1;
