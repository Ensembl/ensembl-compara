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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan_mem_decision

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This module takes pecan jobs, calculates the number of total residues and number of dnafrag. Based on both of this number, it decides which pecan resource should be used to run the job. 
This will hopefully reduce the number of jobs that will be sent to a resource class that is too low, hence will fail after some time and then be passed to a higher memory resource.
if we are able to decide beforehand the right resource memory for most of the jobs, this should save compute time and make the pipeline more efficient.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::Pecan_mem_decision;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
  my $self = shift;
  return {
    %{ $self->SUPER::param_defaults() },
    'synteny_region_id'  => '1628',
    };
}

sub fetch_input
{
	my $self = shift;
	my $synteny_region_id = $self->param_required('synteny_region_id');
	my $query = "select synteny_region_id, sum(dnafrag_end) - sum(dnafrag_start) as total_residues from dnafrag_region group by synteny_region_id having synteny_region_id = $synteny_region_id";
	my $sth = $self->compara_dba->dbc->db_handle->prepare($query);
	$sth->execute();
    my $synteny_residue_map = $sth->fetchall_hashref('synteny_region_id');
    print "\n this is the hash of the synteny total residue \n" if ($self->debug > 3);
    print Dumper($synteny_residue_map) if ($self->debug > 3);
    my $total_residues = $synteny_residue_map->{$synteny_region_id}->{'total_residues'};
    $self->param('total_residues', $total_residues);
    my $query2 = "select synteny_region_id, count(*) as no_dnafrag from dnafrag_region where synteny_region_id = $synteny_region_id";
    my $sth2 = $self->compara_dba->dbc->db_handle->prepare($query2);
	$sth2->execute();
    my $synteny_dnafrag_count = $sth2->fetchall_hashref('synteny_region_id');
    print "\n this is the hash of the synteny total dnafrag \n" if ($self->debug > 3);
    print Dumper($synteny_dnafrag_count) if ($self->debug > 3);
    my $dnafrag_count = $synteny_dnafrag_count->{$synteny_region_id}->{'no_dnafrag'};
    $self->param('dnafrag_count', $dnafrag_count);
}	

sub write_output
{
	my $self = shift;
	my $dataflow_branch = ($self->param('dnafrag_count') > 17) && ( $self->param('total_residues') > 40000000 ) ? '5'
						: ($self->param('dnafrag_count') > 15) && ( $self->param('total_residues') > 20000000 ) ? '4'
						: ($self->param('dnafrag_count') > 11) && ( $self->param('total_residues') > 5000000 ) ? '3'
						: 																						'2'; #default

	print Dumper($dataflow_branch)if ($self->debug > 3);
	 #Flow into pecan
    my $dataflow_output_id = { synteny_region_id => $self->param_required('synteny_region_id') };
    $self->dataflow_output_id($dataflow_output_id,$dataflow_branch);
}
	

1;
