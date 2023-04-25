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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CheckDnaAlnsComplete

=head1 DESCRIPTION

A small runnable to check 'dna_alns_complete'
and fail if its value is 0 (false).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::CheckDnaAlnsComplete;

use warnings;
use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;
    if( ! $self->param_required('dna_alns_complete') ) {

        die "Switch param 'dna_alns_complete' is off ('0').\n"
            . " If all DNA alignments required for WGA coverage are ready, set 'dna_alns_complete' to on ('1') to do WGA coverage analyses.\n"
            . " If any alignments required for WGA coverage are not yet ready, wait until they are ready before setting 'dna_alns_complete' to '1'.\n"
            . " If you are not planning to calculate WGA coverage, forgive this job to skip WGA coverage analyses.\n";
    }
}


1;
