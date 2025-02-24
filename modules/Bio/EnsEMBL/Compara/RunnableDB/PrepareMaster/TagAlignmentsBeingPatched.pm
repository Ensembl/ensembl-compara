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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::TagAlignmentsBeingPatched

=head1 DESCRIPTION

This runnable checks which genomes are being patched in the current release,
and tags the LastZ MLSSes involving patched genomes, so that they will be
redumped automatically during the Compara FTP dumps.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::PrepareMaster::TagAlignmentsBeingPatched;

use strict;
use warnings;

use File::Basename qw(basename);
use File::Spec::Functions qw(catfile);

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $work_dir = $self->param_required('work_dir');

    my $patch_report_pattern = qr/^assembly_patches\.(?<species_name>[a-z0-9_]+)\.txt$/;

    my $glob_expr = catfile($work_dir, 'assembly_patches.*.txt');
    my @patch_report_paths = glob($glob_expr);

    my @patched_species;
    foreach my $patch_report_path (@patch_report_paths) {
        my $patch_report_name = basename($patch_report_path);

        my $species_name = $patch_report_name =~ $patch_report_pattern ? $+{'species_name'} : undef;

        if (! defined $species_name) {
            $self->die_no_retry("failed to extract genome name from patch report file name: $patch_report_name");
        }

        my $report_contents = $self->_slurp($patch_report_path);
        chomp $report_contents;

        if ($report_contents ne 'No patch updates found') {
            push(@patched_species, $species_name);
        }
    }

    $self->param('patched_species', \@patched_species);
}


sub write_output {
    my $self = shift;

    my $patched_species = $self->param('patched_species');
    my $master_db = $self->param_required('master_db');
    my $release = $self->param_required('release');

    my $master_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba($master_db);
    my $mlss_dba = $master_dba->get_MethodLinkSpeciesSetAdaptor();
    my $genome_dba = $master_dba->get_GenomeDBAdaptor();

    my @patchable_method_types = ('LASTZ_NET');

    my @mlsses_being_patched;
    foreach my $species_name (@{$patched_species}) {
        my $genome_db = $genome_dba->fetch_by_name_assembly($species_name);

        foreach my $method_type (@patchable_method_types) {
            my $mlsses_of_type = $mlss_dba->fetch_all_by_method_link_type_GenomeDB($method_type, $genome_db);
            foreach my $mlss (@{$mlsses_of_type}) {
                if ($mlss->is_current && $mlss->first_release < $release) {
                    push(@mlsses_being_patched, $mlss);
                }
            }
        }
    }

    my $tag = "patched_in_${release}";
    foreach my $mlss (@mlsses_being_patched) {
        $mlss->store_tag($tag, 1);
    }
}


1;
