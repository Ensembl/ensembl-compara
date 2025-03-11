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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpConservationScores

=head1 SYNOPSIS

Wrapper around dump_features.pl to dump conservation scores, but for
a given list of regions given in the "chunkset" parameter.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::DumpConservationScores;

use strict;
use warnings;

use File::Basename;
use File::Path qw(make_path);

use Bio::EnsEMBL::Compara::Utils::FlatFile qw(check_for_null_characters);
use Bio::EnsEMBL::Hive::Utils qw(destringify dir_revhash);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },
        'this_bedgraph' => '#work_dir#/#dirname#/#hash_dir#/#name#.#chunkset_id#.bedgraph',
        'cmd'           => '#dump_features_exe# --feature cs_#mlss_id# --compara_db #compara_db# --species #name# --regions "#regions_bed_file#" --reg_conf "#registry#" > #this_bedgraph#',
        'healthcheck_list' => [],
    }
}


sub fetch_input {
    my $self = shift;

    my $filename = $self->worker_temp_directory . "/regions.bed";
    open(my $fh, '>', $filename);
    foreach my $aref (@{$self->param_required('chunkset')}) {
        print $fh join("\t", $aref->[0], $aref->[1]-1, $aref->[2]), "\n";
    }
    close $fh;
    $self->param('regions_bed_file', $filename);

    my $rev_hash = dir_revhash($self->param_required('chunkset_id'));
    $self->param('hash_dir', $rev_hash);

    make_path(dirname($self->param_required('this_bedgraph')));
}


sub run {
    my $self = shift @_;
    $self->run_command( $self->param_required('cmd'), { die_on_failure => 1 });
}


sub write_output {
    my $self = shift @_;

    # check for empty files
    if ( $self->_check_if_empty_record ) {
        $self->input_job->autoflow(0);
        my $empty_file_msg = "No conservation scores found for these regions in " . $self->param('name') . "... Skipping!\n";
        $self->complete_early( $empty_file_msg );
    }

    if ($self->param_is_defined('healthcheck_list')) {
        $self->_healthcheck();
    }
}

#
# Check file has data, not just a header
#
sub _check_if_empty_record {
    my ($self) = @_;
    
    my $output_file = $self->param('this_bedgraph');

    my $wc_cmd = "wc -l $output_file | awk '{print \$1}'";
    my $run_cmd = $self->run_command($wc_cmd, { die_on_failure => 1 });

    return 1 if ( int($run_cmd->out) < 2 ); # file contains nothing/header only
    return 0; # file contains records
}

sub _healthcheck {
    my $self = shift;

    my $healthcheck_list = destringify($self->param('healthcheck_list'));
    my $output_file = $self->param('this_bedgraph');

    foreach my $hc_type (@{$healthcheck_list}) {
        if ( $hc_type eq 'unexpected_nulls' ) {
            check_for_null_characters($output_file);
        } else {
            $self->die_no_retry("Healthcheck type '$hc_type' not recognised");
        }
    }
}

1;
