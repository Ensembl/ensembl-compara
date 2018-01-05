
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::RAxML;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return {
             %{$self->SUPER::param_defaults},
             'cmd'                        => '#raxml_exe# #extra_raxml_args# -m #best_fit_model# -p 99123746531 -t gene_tree_#gene_tree_id#.nhx -s #alignment_file# -n #gene_tree_id#',
             'extra_raxml_args'           => '',
             'raxml_number_of_cores'      => 1,
             'runtime_tree_tag'           => 'raxml_runtime',
             'remove_columns'             => 1,
             'run_treebest_sdi'           => 1,
             'reroot_with_sdi'            => 1,
             'input_clusterset_id'        => 'raxml_parsimony',
             'output_file'                => 'RAxML_result.#gene_tree_id#',
             'minimum_genes'              => 4,
			 'output_clusterset_id'       => 'raxml',
    };
}

sub run {
    my $self = shift;
    $self->raxml_exe_decision();
    my $best_fit_model = $self->set_raxml_model();
    $self->param( 'best_fit_model', $best_fit_model );
    print "best-fit model: " . $self->param('best_fit_model') . "\n" if ( $self->debug );
    $self->SUPER::run(@_)
    #sleep(600);
}

##########################################
#
# internal methods
#
##########################################
sub set_raxml_model {
    my $self = shift;

    # For DNA models, we don't have the choice
    return "GTRGAMMA" if $self->param('cdna');

    if ( !$self->param('gene_tree')->has_tag('best_fit_model_family') ) {

        # LG was the most common best-model, but we dont have it in RAxML.
        # We use the second most common one instead: JTT
        return "PROTGAMMAJTT";
    }
    my $raxml_bestfit_model            = $self->param('gene_tree')->get_value_for_tag('best_fit_model_family');
    my $raxml_bestfit_model_parameters = $self->param('gene_tree')->get_value_for_tag('best_fit_model_parameter');
    my $raxml_model;

    if ( $raxml_bestfit_model !~ /^(DAYHOFF|DCMUT|JTT|MTREV|WAG|RTREV|CPREV|VT|BLOSUM62|MTMAM)$/ ) {
        $raxml_bestfit_model = "JTT";
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model;
    }
    elsif ( $raxml_bestfit_model_parameters eq "" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model;
    }
    elsif ( $raxml_bestfit_model_parameters eq "F" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model . "F";
    }
    elsif ( $raxml_bestfit_model_parameters eq "G" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model;
    }
    elsif ( $raxml_bestfit_model_parameters eq "GF" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model . "F";
    }
    elsif ( $raxml_bestfit_model_parameters eq "I" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model;
    }
    elsif ( $raxml_bestfit_model_parameters eq "IF" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model . "F";
    }
    elsif ( $raxml_bestfit_model_parameters eq "IG" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model;
    }
    elsif ( $raxml_bestfit_model_parameters eq "IGF" ) {
        $raxml_model = "PROTGAMMA" . $raxml_bestfit_model . "F";
    }
    else {
        return "PROTCATJTT";
    }

    print "best-fit model:$raxml_bestfit_model\n" if ( $self->debug );

    return $raxml_model;
}

1;
