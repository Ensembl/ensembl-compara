=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::DumpChrs2Multifasta

=head1 SYNOPSIS

Dump all toplevel chromosome DNA sequences to multifasta for sketching

=head1 DESCRIPTION

=cut

package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::DumpChrs2Multifasta;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
	my $self = shift;

	my $dump_script = $self->param_required('dump_genome_script');
	my $gdb_id      = $self->param_required('genome_db_id');
	my $compara_db  = $self->param_required('compara_db');
	my $outfile     = $self->param('outfile_prefix') . ".fa";

	my $cmd = "$dump_script --compara $compara_db --genome_db_id $gdb_id --outfile $outfile --multifasta";
	system($cmd);
}

sub write_output {
	my $self = shift;
	$self->dataflow_output_id( { input_file => $self->param('outfile_prefix') . ".fa" }, 1 );
}

1;