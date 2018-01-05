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

    my $ref_ortholog_dba    = $self->get_cached_compara_dba('ref_ortholog_db');
    my $ref_mlss_adaptor    = $ref_ortholog_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss_adaptor        = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my %homology_methods    = map {$_ => 1} qw(ENSEMBL_ORTHOLOGUES ENSEMBL_PARALOGUES ENSEMBL_HOMOEOLOGUES);
    my @overlapping_mlsss   = grep {$mlss_adaptor->fetch_by_dbID($_->dbID)}
                              grep {$homology_methods{$_->method->type}}
                                   @{$ref_mlss_adaptor->fetch_all};

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
}

1; 
