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

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpSpeciesDBToTSV

=head1 DESCRIPTION

Takes a compara registry alias to output the corresponding database name.
Gets the required parameters for and runs the python script to dump homologies to a tsv file. 


=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::DumpSpeciesDBToTsv;

use warnings;
use strict;
use File::Path;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;
    my $ref_db = $self->param('rr_ref_db');
    my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($ref_db);
    my $compara_db = $dba->dbc->dbname;
    $self->param('compara_db', $compara_db);
    my $filename = $self->param('species_name') . '-' . $self->param('assembly') . '-' . $self->param('geneset') . '-' . 'homology' . '.tsv';
    $self->param('filename', $filename);
    my $filepath = $self->param('output_dir') .'/'. $self->param('filename');
    $self->param('filepath', $filepath);
}

sub run {
    my $self = shift;
    mkpath($self->param('output_dir'),1,0777);
    my $dump_homologies_script = $self->param('dump_homologies_script');
    my $db_url = $self->param('per_species_db');
    my $ref_db = $self->param('rr_ref_db');
    my $out_dir = $self->param('output_dir');
    my $filename = $self->param('filename');
    my $compara_db = $self->param('compara_db');
    my $filepath = $self->param('filepath');
    my $cmd = "python $dump_homologies_script -u $db_url -r $compara_db -o $out_dir/$filename";
    my $run_cmd = $self->run_command($cmd, { 'die_on_failure' => 1});
    print "Time for dumping the homologies... " . $run_cmd->runtime_msec . " msec\n";
}

sub write_output {
	my $self = shift;
	my $output_id = {
		filepath    => $self->param_required('filepath'),
	};

	$self->dataflow_output_id( $output_id, 2 );

}
1;

