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

Bio::EnsEMBL::Compara::RunnableDB::ParseQueryToUpdateList

=head1 DESCRIPTION

Runnable to parse the record of query genomes to each reference genome
that has been updated during the reference update in rapid release

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ParseQueryToUpdateList;

use warnings;
use strict;
use List::MoreUtils qw/ uniq /;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'queries_to_update_file'  => 'queries_to_update.txt',
    };
}

sub write_output {
    my $self = shift;

    # Updated reference genome production name
    my $genome     = $self->param_required("species_name");
    my $record_dir = $self->param_required("species_set_record");
    my @records    = glob "${record_dir}/*/${genome}.txt";
    my $out_file   = $self->param("queries_to_update_file");
    my @queries;

    foreach my $file ( @records ) {
        my $contents = $self->_slurp( $file );
        push @queries, ( split( /\n/, $contents ) );
        my $cmd = "mv --force $file $file" . ".used";
        $self->run_command($cmd);
    }
    my @query_list = sort ( uniq( @queries ) );
    $self->_spurt( $out_file, join( "\n", @query_list, 1 ) );
    $self->dataflow_output_id( { 'queries_to_update' => \@query_list }, 1);

}

1;
