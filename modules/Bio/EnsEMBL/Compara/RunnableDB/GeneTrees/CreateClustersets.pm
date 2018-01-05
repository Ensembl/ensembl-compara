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
  <http://www.ensembl.org/Help/Contact>

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets

=head1 DESCRIPTION

This Analysis/Runnable is designed to store additional geneTree clustersets
That will be needed by the rest of the pipeline

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded by an underscore (_).

=cut 

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::CreateClustersets;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters');

sub run {
    my ($self) = @_;

    foreach my $clusterset_id (@{$self->param_required('additional_clustersets')}) {
        $self->fetch_or_create_clusterset($clusterset_id);
    }
}

1;
