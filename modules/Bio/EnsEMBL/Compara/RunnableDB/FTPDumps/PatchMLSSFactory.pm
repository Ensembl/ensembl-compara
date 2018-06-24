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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchMLSSFactory

=head1 SYNOPSIS

	Fan out all LASTZ_NET mlss_id found in $self->param('lastz_patch_dbs')

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::PatchMLSSFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

        $self->load_registry($self->param('reg_conf')) if $self->param('reg_conf');

	my @dataflow_jobs;
	foreach my $patch_db ( @{ $self->param('lastz_patch_dbs') } ) {
		my $patch_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $patch_db );
		foreach my $this_mlss ( @{ $patch_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type("LASTZ_NET") } ) {
			push( @dataflow_jobs, { mlss_id => $this_mlss->dbID, patch_db => $patch_db } );
		}
	}

	print Dumper \@dataflow_jobs;
	$self->param( 'dataflow_jobs', \@dataflow_jobs );
}

sub write_output {
	my $self = shift;

	$self->dataflow_output_id( $self->param('dataflow_jobs'), 2 );
}

1;
