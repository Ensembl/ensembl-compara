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

Bio::EnsEMBL::Compara::RunnableDB::DumpAncestralAlleles::GenomeDBFactory

=head1 SYNOPSIS

	Find the most recent primate EPO run and flow the names of its member species

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpAncestralAlleles::GenomeDBFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $registry = 'Bio::EnsEMBL::Registry';
	$registry->load_all($self->param('reg_conf'), 0, 0, 0, "throw_if_missing") if $self->param('reg_conf');

	my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('compara_db') );
	my $mlss_adap = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

	my $primate_epo_mlss = $mlss_adap->fetch_by_method_link_type_species_set_name('EPO', 'primates');
	# my @species_list = map {$_->name} @{ $primate_epo_mlss->species_set->genome_dbs };
	$self->param('mlss', $primate_epo_mlss);
	# $self->param('species_list', \@species_list);
}

sub write_output {
	my $self = shift;

	# foreach my $species_name ( @{ $self->param('species_list') } ) {
	# 	print "FLOWING: $species_name\n";
	# 	$self->dataflow_output_id( { species_name => $species_name }, 2 );
	# }

	foreach my $gdb ( @{ $self->param('mlss')->species_set->genome_dbs } ) {
		my $dirname = $gdb->name . '_ancestor_' . $gdb->assembly;
		$self->dataflow_output_id( { species_dir => $dirname, species_name => $gdb->name }, 2 );
	}
}

1;
