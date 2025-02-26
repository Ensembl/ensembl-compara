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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FlowAnyMissingMLSSes

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FlowAnyMissingMLSSes;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub write_output {
    my $self = shift;

    my $missing_mlss_ids = $self->param('missing_mlss_id');

    if (defined $missing_mlss_ids && scalar(@$missing_mlss_ids) > 0) {
         $self->dataflow_output_id( { mlss_ids => $missing_mlss_ids, reuse_prev_rel => 0 }, 2 );
    }
}

1;
