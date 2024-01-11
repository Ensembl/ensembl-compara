=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

=head1 NAME

Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees

=head1 DESCRIPTION  

This PipeConfig contains the core analyses required to dump all the
species-trees from the given compara database.

=cut

package Bio::EnsEMBL::Compara::PipeConfig::Parts::DumpSpeciesTrees;

use strict;
use warnings;

use Bio::EnsEMBL::Hive::Version 2.4;
use Bio::EnsEMBL::Hive::PipeConfig::HiveGeneric_conf;

sub pipeline_analyses_dump_species_trees {
    my ($self) = @_;

    return [
        {   -logic_name => 'mk_species_trees_dump_dir',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd'           => ['mkdir', '-p', '#dump_dir#'],
            },
            # -input_ids  => [{ }],
            -flow_into  => ['dump_factory'],
        },

        {   -logic_name => 'dump_factory',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::JobFactory',
            -rc_name    => '1Gb_job',
            -parameters => {
                'db_conn'       => '#compara_db#',
                'inputquery'    => 'SELECT root_id, label, method_link_id, replace(name, " ", "_") as name FROM species_tree_root JOIN method_link_species_set USING (method_link_species_set_id)',
            },
            -flow_into => {
                2 => WHEN( '((#method_link_id# eq "401") || (#method_link_id# eq "402")) && (#label# ne "cafe")' => {'dump_one_tree_without_distances' => INPUT_PLUS() },
                           ELSE { 'dump_one_tree_with_distances' => INPUT_PLUS() },
                ),
            },
        },

        {   -logic_name => 'dump_one_tree_with_distances',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd'           => '#dump_species_tree_exe# -compara_db #compara_db# -reg_conf #reg_conf# --stn_root_id #root_id# -with_distances > "#dump_dir#/#name#_#label#.nh"',
            },
            -flow_into  => [ 'sanitize_file' ],
        },

        {   -logic_name => 'dump_one_tree_without_distances',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd'           => '#dump_species_tree_exe# -compara_db #compara_db# -reg_conf #reg_conf# --stn_root_id #root_id# > "#dump_dir#/#name#_#label#.nh"',
            },
            -flow_into  => [ 'sanitize_file' ],
        },

        {   -logic_name => 'sanitize_file',
            -module     => 'Bio::EnsEMBL::Hive::RunnableDB::SystemCmd',
            -rc_name    => '1Gb_job',
            -parameters => {
                'cmd'           => ['sed', '-i', 's/  */_/g', '#dump_dir#/#name#_#label#.nh'],
            },
        },
    ];
}
1;
