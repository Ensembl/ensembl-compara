=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory

=cut

=head1 SYNOPSIS

my $aa = $sdba->get_AnalysisAdaptor;
my $analysis = $aa->fetch_by_logic_name('MLSSIDFactory');
my $rdb = new Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory(
                         -input_id   => [[1,2,3,14],[4,13],[11,16]]
                         -analysis   => $analysis);

$rdb->fetch_input
$rdb->run;

=cut

=head1 DESCRIPTION

This is a homology compara specific runnableDB, that based on an input
of arrayrefs of genome_db_ids, creates Homology_dNdS jobs in the hive 
analysis_job table.

=cut

=head1 CONTACT

abel@ebi.ac.uk, jessica@ebi.ac.uk

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $species_set       = $self->param_required('species_set');
    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    my @mlss_ids = ();
    while (my $genome_db_id1 = shift @{$species_set}) {
        push @mlss_ids, $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_PARALOGUES', [$genome_db_id1])->dbID;
        foreach my $genome_db_id2 (@{$species_set}) {
            push @mlss_ids, $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES', [$genome_db_id1, $genome_db_id2])->dbID;
        }
    }

    $self->param('inputlist', \@mlss_ids);
}


sub write_output {
    my $self = shift @_;

    my $inputlist  = $self->param('inputlist');

    while (@$inputlist) {
        $self->dataflow_output_id( { 'mlss_id' => shift @$inputlist }, 2);
    }
}

1;
