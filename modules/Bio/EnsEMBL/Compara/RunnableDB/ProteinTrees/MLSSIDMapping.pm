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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDMapping

=cut

=head1 SYNOPSIS

Required inputs:
	- mlss_id of an homology analysis
	- URL pointing to the previous release database
	- pointer to current database (usually doesn't require explicit definition)

Example:
	standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDMapping
        -compara_db mysql://ensro@compara5/cc21_protein_trees_no_reuse_86 -mlss_id 101307 -prev_rel_db mysql://ensro@compara5/wa2_ensembl_compara_85

=cut

=head1 DESCRIPTION

Simple Runnable that finds the mlss_id of the previous database that links
the same species (same name, assemblies can be different) with the same method.

The mapping is stored as an mlss_tag.

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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MLSSIDMapping;

use strict;
use warnings;

use List::MoreUtils qw(all);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my $self = shift;

	my $mlss_id         = $self->param_required('mlss_id');
	my $mlss            = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id);
        my $current_gdbs    = $mlss->species_set->genome_dbs;

	my $previous_compara_dba    = $self->get_cached_compara_dba('prev_rel_db');
	my $previous_gdb_adaptor    = $previous_compara_dba->get_GenomeDBAdaptor;
	my $previous_mlss_adaptor   = $previous_compara_dba->get_MethodLinkSpeciesSetAdaptor;

        my @previous_gdbs           = map {$previous_gdb_adaptor->fetch_by_name_assembly($_->name)} @$current_gdbs;
        my $previous_mlss_id;

        if (all {defined $_} @previous_gdbs) {
            # All could be mapped -> the MLSS probably can be mapped as
            # well
            my $previous_mlss = $previous_mlss_adaptor->fetch_by_method_link_type_GenomeDBs($mlss->method->type, \@previous_gdbs);
            $previous_mlss_id = $previous_mlss->dbID if $previous_mlss;
        }

        $self->dataflow_output_id( { 'previous_mlss_id' => $previous_mlss_id }, 1);
}


1;
