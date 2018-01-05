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
of arrayrefs of genome_db_ids, flows jobs for each homology MLSS

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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'methods'       => {
            'ENSEMBL_PARALOGUES'    => 2,
            'ENSEMBL_ORTHOLOGUES'   => 2,
            'ENSEMBL_HOMOEOLOGUES'  => 2,
        },
    }
}

sub fetch_input {
    my $self = shift @_;

    my $genome_db_ids = $self->param_required('genome_db_ids');

    while (my $genome_db_id1 = shift @{$genome_db_ids}) {
        $self->make_dataflow_if_needed('ENSEMBL_PARALOGUES', [$genome_db_id1]);

        if ($self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id1)->is_polyploid) {
            $self->make_dataflow_if_needed('ENSEMBL_HOMOEOLOGUES', [$genome_db_id1]);
        }
        
        foreach my $genome_db_id2 (@{$genome_db_ids}) {
            $self->make_dataflow_if_needed('ENSEMBL_ORTHOLOGUES', [$genome_db_id1, $genome_db_id2]);
        }
    }
}

sub make_dataflow_if_needed {
    my ($self, $method, $genome_db_ids) = @_;
    return unless $self->param('methods')->{$method};

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids($method, $genome_db_ids)
                || die "Could not find the MLSS with the method '$method' and the genome_db_ids ".join('/', @$genome_db_ids)."\n";
    $self->dataflow_output_id( { 'homo_mlss_id' => $mlss->dbID }, $self->param('methods')->{$method});
}

1;
