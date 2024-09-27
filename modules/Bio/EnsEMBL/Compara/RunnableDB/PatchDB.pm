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

Bio::EnsEMBL::Compara::RunnableDB::PatchDB

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::PatchDB;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'ignore_failure' => 0,
        'record_output'  => 0,
    }
}

sub run {
	my $self = shift;

    my $patch_file = $self->param_required('patch_file');
    die "Cannot find patch file $patch_file" unless -e $patch_file;

	my $dbc = $self->get_cached_compara_dba('db_conn')->dbc;
	my $cmd = "mysql -h " . $dbc->host . ' -P ' . $dbc->port . ' -u ' . $dbc->user . ' -p' . $dbc->pass . ' ' . $dbc->dbname . " < $patch_file";
	my $patch_run = $self->run_command($cmd);

    my $err = $patch_run->err;
    $err =~ s/mysql: \[Warning\] Using a password on the command line interface can be insecure.\s*//gi; # account for expected err
	if ( $err ne '' ) {
		if ( $self->param('ignore_failure') ) {
			$self->warning("STDERR: " . $patch_run->err);
			$self->input_job->autoflow(0);
			$self->complete_early("Ignoring failure");
		} else {
			die $patch_run->err;
		}
	}

	if ($self->param('record_output')){
		$self->param('patch_output', $patch_run->out);
		$self->warning($self->param('patch_output'));
	}
}

1;
