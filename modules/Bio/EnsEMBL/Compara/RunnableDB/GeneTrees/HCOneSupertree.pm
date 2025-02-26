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

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HCOneSupertree

=head1 DESCRIPTION

This runnable calls supertree healthchecks for the
supertree referred to by parameter 'gene_tree_id'.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::HCOneSupertree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self= shift @_;

    Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SqlHealthChecks::_embedded_call($self, 'supertrees');
}


1;
