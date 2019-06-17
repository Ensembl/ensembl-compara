=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::LoadMembers_conf

=head1 DESCRIPTION

    Specialized version of the LoadMembers pipeline for Ensembl Genomes

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::Plants::LoadMembers_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::LoadMembers_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

    # parameters inherited from EnsemblGeneric_conf and very unlikely to be redefined:
        # It defaults to Bio::EnsEMBL::ApiVersion::software_version()
        # 'ensembl_release'       => 68,

    # parameters that are likely to change from execution to another:
        # It is very important to check that this value is current (commented out to make it obligatory to specify)
        # Change this one to allow multiple runs
        #'rel_suffix' => 'b',

        'division'    => 'plants',
        'collection'  => $self->o('division'),

        # names of species we don't want to reuse this time
        #'do_not_reuse_list'     => [ 'homo_sapiens', 'mus_musculus', 'rattus_norvegicus', 'mus_spretus_spreteij', 'danio_rerio', 'sus_scrofa' ],
        'do_not_reuse_list'     => [ ],

    # "Member" parameters:
        'allow_ambiguity_codes'     => 1,
        # Genes with these logic_names will be ignored from the pipeline.
        # Format is { genome_db_id (or name) => [ 'logic_name1', 'logic_name2', ... ] }
        # An empty string can also be used as the key to define logic_names excluded from *all* species
        'exclude_gene_analysis'     => {},
        # Store protein-coding genes
        'store_coding'              => 1,
        # Store ncRNA genes
        'store_ncrna'               => 0,
        # Store other genes
        'store_others'              => 0,

    #load uniprot members for family pipeline
        'load_uniprot_members'      => 0,

    };
}


1;

