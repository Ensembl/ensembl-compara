=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::RunJavaHealthCheck

=head1 SYNOPSIS

Runs an EnsEMBL Java Healthcheck (see https://github.com/Ensembl/ensj-healthcheck)
Requires several inputs:
    'output_file' : to pipe the output from java to
    'compara_db'  : db to run the HC on
    ['testgroup'|'testcase'] : either a testgroup or testcase must be defined (see
                               ensj-healthcheck for more)
    'forgive'     : forgive failures of the HCs and autoflow

=cut

package Bio::EnsEMBL::Compara::RunnableDB::RunJavaHealthCheck;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'forgive' => 0,
    }
}

sub fetch_input {
    my $self = shift;

    if ( $self->param('forgive') ) {
        # when HC is unfixable/forgivable, don't run again - just autoflow
        $self->input_job->autoflow(0);
        $self->complete_early("HCs forgiven - autoflowing");
    }

    my $hc_output_file = $self->param_required('output_file');
    if ($self->param('hc_version')) {
        $hc_output_file .= '.' . $self->param('hc_version');
        $self->param('output_file', $hc_output_file);
    }

    my $cmd = join(' ',
        $self->param_required('run_healthchecks_exe'),
        '--url'                 => $self->compara_dba->url,
        '--ensj-json-config'    => $self->param_required('ensj_conf'),
        '--ensj-testrunner'     => $self->param_required('ensj_testrunner_exe'),
    );

    if ( $self->param('master_db') ) {
        my $master_url = $self->get_cached_compara_dba('master_db')->url;
        $cmd .= "--master_db " . $master_url . " ";
    } else {
        # Since there is no registry, we can't even default to "compara_master"
        $cmd .= " --master_db '' ";
    }

    if( $self->param('testgroup') ) {
        $cmd .= '-g ' . $self->param('testgroup');
    } elsif ( $self->param('testcase') ) {
        $cmd .= '-t ' . $self->param('testcase');
    } else {
        die "Either 'testgroup' or 'testcase' must be defined\n";
    }

    $cmd .= " > $hc_output_file";
    $self->param('cmd', $cmd);
}

sub run {
    my $self = shift;

    $self->run_command($self->param_required('cmd'), {die_on_failure => 1});
}

sub write_output {
    my $self = shift;

    # increment number for versioning the output file
    if ( $self->param('hc_version') ) {
        $self->db->hive_pipeline->add_new_or_update('PipelineWideParameters',
            'param_name' => 'hc_version',
            'param_value' => $self->param_required('hc_version') + 1,
        );
        $self->db->hive_pipeline->save_collections();
    }

    my $hc_output_file = $self->param_required('output_file');
    die "Detected HC failure! Check $hc_output_file for details\n" if $self->grep_file('FAIL', $hc_output_file);
}

sub grep_file {
    my ( $self, $term, $file ) = @_;

    my $grep_run = $self->run_command("grep -m 1 '$term' $file");
    my $grep_output = $grep_run->out;
    if ( $grep_output eq '' || !defined $grep_output ) {
        return 0;
    } else {
        return 1;
    }
}

1;
