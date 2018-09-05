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

=head1 NAME

  Bio::EnsEMBL::Compara::PipeConfig::EBI::GRCh37::ProteinTrees_conf

=head1 DESCRIPTION

    The PipeConfig file for ProteinTrees pipeline that should automate most of the pre-execution tasks.


=head1 CONTACT

  Please contact Compara or Ensembl Genomes with questions/suggestions

=cut

package Bio::EnsEMBL::Compara::PipeConfig::EBI::GRCh37::ProteinTrees_conf;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::ProteinTrees_conf');


sub default_options {
    my ($self) = @_;

    return {
        %{$self->SUPER::default_options},   # inherit the generic ones

        # the production database itself (will be created)
        # it inherits most of the properties from HiveGeneric, we usually only need to redefine the host, but you may want to also redefine 'port'

        'host'  => 'mysql-ens-compara-prod-2.ebi.ac.uk',
        'port'  => 4522,

    # User details

    # parameters that are likely to change from execution to another:
        # You can add a letter to distinguish this run from other runs on the same release

        'test_mode' => 1, #set this to 0 if this is production run
        
        'rel_suffix'            => '',
        # names of species we don't want to reuse this time
        'do_not_reuse_list'     => [ ],

        # Tag attached to every single tree
        'division'              => 'ensembl',

    # species tree reconciliation
        # you can define your own species_tree for 'notung' or 'CAFE'. It *has* to be binary
        'binary_species_tree_input_file'   => undef,

    # connection parameters to various databases:

        # the master database for synchronization of various ids (use undef if you don't have a master database)
        'master_db' => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_master_grch37',

        # Add the database location of the previous Compara release. Leave commented out if running the pipeline without reuse
        'prev_rel_db' => 'mysql://ensro@mysql-ens-grch37-mirror.ebi.ac.uk:4603/ensembl_compara_93',

        # Where the members come from (as loaded by the LoadMembers pipeline)
        'member_db'   => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/muffato_load_members_94_grch37',

        # Points to the previous production database. Will be used for various GOC operations.
        'goc_reuse_db'          => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/grch37_ens_compara_87_reuse_goc',
        #'mapping_db'            => 'mysql://ensro@mysql-ens-compara-prod-2.ebi.ac.uk:4522/waakanni_protein_trees_88',
    };
}


1;

