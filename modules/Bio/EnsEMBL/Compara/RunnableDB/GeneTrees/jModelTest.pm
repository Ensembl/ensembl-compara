
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

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::jModelTest;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },
        'cmd'               => '#java_exe# -jar #modeltest_jar# -d #alignment_file# -s 11 -g 4 -i -f -#criteria# -a -tr #n_cores#',
        'runtime_tree_tag'  => 'jmodeltest_runtime',
        'remove_columns'    => 1,
        'read_tags'         => 1,
        'output_file'       => '#gene_tree_id#.jmodeltest',
        'minimum_genes'     => 4,
        'criteria'          => 'BIC',
        'n_cores'           => 1,
    };
}

sub fetch_input {
    my $self = shift;

    if (!$self->param('cdna')) {
        $self->complete_early("jModelTest is skipped if NOT in 'cdna' mode");
    }

    #Give back control to fetch_input in GenericRunnable
    return $self->SUPER::fetch_input(@_);

}

sub run {
    my $self = shift;

    if ($self->param('gene_tree')->has_tag('nucleotide_best_fit_model_family')) {
        $self->complete_early("Already has best-fit model");
    }

    #Give back control to run in GenericRunnable
    return $self->SUPER::run(@_);

}

##########################################
#
# internal methods
#
##########################################

sub get_tags {
    my $self = shift;

    my %best_fit_model;
    my %best_fit_param;

    open( my $output_file, "<", $self->param('output_file') );
    while (<$output_file>) {
        if ( $_ =~ /^Model selected:/ ) {
            my $empty_line = <$output_file>;
            chomp($_);
            my @tok = split( /\= /, $_ );
            $best_fit_model{$self->param('criteria')} = $tok[1];

            #print "AIC:$tok[1]\n";
        }

    }

    my $model = $best_fit_model{ $self->param('criteria') };

    my $model_family = $model;
    my $model_parameters = '';

    if ( $model =~ /\+/ ) {
        my @tok = split( /\+/, $model );
        $model_family = shift(@tok);
        $model_parameters = join( "", @tok );
    }

    print "best-fit model: $model_family\nmodel parameters: $model_parameters\n" if $self->debug;

    return { 'best_fit_model_family' => $model_family , 'best_fit_model_parameter' => $model_parameters};

}

1;
