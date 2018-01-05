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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('HomologyGroupingFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, flows Homology_dNdS jobs.

=cut

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HomologyGroupingFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'group_size'         => 1000,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $mlss_id = $self->param_required('homo_mlss_id');

    my $sql = 'SELECT homology_id FROM homology WHERE method_link_species_set_id = ? AND description != "gene_split" ORDER BY homology_id';
    my $sth = $self->compara_dba->dbc->prepare($sql);

    my @homology_ids = ();
    $sth->execute($mlss_id);
    while( my ($homology_id) = $sth->fetchrow() ) {
        push @homology_ids, $homology_id;
    }

    $self->param('inputlist', \@homology_ids);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');
    my $group_size = $self->param('group_size');

    $self->input_job->autoflow(0) if scalar(@$inputlist) == 0;

    while (@$inputlist) {
        my @job_array = splice(@$inputlist, 0, $group_size);
        $self->dataflow_output_id( { 'mlss_id' => $self->param('homo_mlss_id'), 'min_homology_id' => $job_array[0], 'max_homology_id' => $job_array[-1] }, 2);
        $self->dataflow_output_id( { 'mlss_id' => $self->param('homo_mlss_id'), 'homology_ids' => \@job_array }, 3 ); # to homology_id_mapping
    }
}

1;
