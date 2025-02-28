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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory;

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::MLSSJobFactory;

use strict;
use warnings;

use File::Path qw(make_path remove_tree);


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my ($self) = @_;
    return {
        %{$self->SUPER::param_defaults},
        'from_first_release' => 40, # dump method_link_species_sets with a first_release > this option
        'add_conservation_scores'   => 1,       # When set, will add the conservation scores to the EMF dumps
    }
}

sub run {
    my ($self) = @_;

    # Get MethodLinkSpeciesSet adaptor:
    my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;

    if ($self->param('mlss_id')) {
        my $mlss = $mlssa->fetch_by_dbID($self->param('mlss_id')) ||
            die $self->param('mlss_id')." does not exist in the database !\n";
        $self->_process_mlss($mlss);
        return;
    }

    my $updated_mlss_ids = $self->param('updated_mlss_ids');
    foreach my $ml_typ (split /[,:]/, $self->param_required('method_link_types')){
        # Get MethodLinkSpeciesSet Objects for required method_link_type
        my $mlss_listref = $mlssa->fetch_all_by_method_link_type($ml_typ);
        foreach my $mlss (@$mlss_listref) {
            my $from_first_release = $self->param('from_first_release');
            if ( defined $from_first_release ) {
                my $mlss_dump_wanted = ($mlss->first_release == $from_first_release
                                        || $mlss->has_tag("patched_in_${from_first_release}")
                                        || $mlss->has_tag("rerun_in_${from_first_release}")
                                        || grep { $mlss->dbID eq $_ } @$updated_mlss_ids);
                next unless $mlss_dump_wanted;
            }
            $self->_process_mlss($mlss);
        }
    }
}

sub _process_mlss {
    my ($self, $mlss) = @_;

    $self->_check_valid_type($mlss);

    my $extra_params = {};
    if ($self->param('split_by_chromosome')) {
        # We only need a reference species if we want to split the files by chromosome name
        $extra_params = $self->_check_reference_species($mlss);
    }

    $self->_dataflow_mlss($mlss, $extra_params);
}

sub _check_valid_type {
    my ($self, $mlss) = @_;

    unless ($mlss->method->class =~ /^GenomicAlign/) {
        die sprintf("%s (%s) MLSSs cannot be dumped with this pipeline !\n", $mlss->method->type, $mlss->method->class);
    }
    if ($mlss->method->type =~ /^(CACTUS_HAL|CACTUS_HAL_PW|CACTUS_DB)$/) {
        die "Cactus alignments cannot be dumped because they already exist as files\n";
    }
}

sub _check_reference_species {
    my ($self, $mlss) = @_;

    my $mlss_id     = $mlss->dbID();

    if ($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment') {
        my $ref_species = $mlss->get_value_for_tag('reference_species');
        die "Reference species missing! Please check the 'reference species' tag in method_link_species_set_tag for mlss_id $mlss_id\n" unless $ref_species;

    } else {
        my %species_in_mlss = map {$_->name => 1} @{$mlss->species_set->genome_dbs};
        my @ref_species_in = grep {$species_in_mlss{$_}} @{$self->param('species_priority')};
        if (not scalar(@ref_species_in)) {
            die "Could not find any of (".join(", ", map {'"'.$_.'"'} @{$self->param('species_priority')}).") in mlss_id $mlss_id. Edit the 'species_priority' list in MLSSJobFactory.\n";
        }
        $mlss->add_tag('reference_species', $ref_species_in[0]);
    }

    #Note this is using the database set in $self->param('compara_db') rather than the underlying eHive database.
    my $compara_dba       = $self->compara_dba;
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my $genome_component  = $mlss->has_tag('reference_component') ? $mlss->get_value_for_tag('reference_component') : undef;
    my $species_name      = $mlss->get_value_for_tag('reference_species');

    my $genome_db         = $genome_db_adaptor->fetch_by_name_assembly($species_name) || $genome_db_adaptor->fetch_by_registry_name($species_name);
    $genome_db            = $genome_db->component_genome_dbs($mlss->get_value_for_tag('reference_component')) if $mlss->has_tag('reference_component');

    $genome_db->db_adaptor || die "I don't know where the '$species_name' core database is. Have you defined the Registry ?\n";
    
    return {
        species         => $species_name,
        genome_db_id    => $genome_db->dbID,
    };
}

sub _dataflow_mlss {
    my ($self, $mlss, $extra_params) = @_;

    my $mlss_id     = $mlss->dbID();
    my $filename = $mlss->filename;

    if ($self->param('add_conservation_scores')) {
        my $cs_mlsss = $mlss->get_all_sister_mlss_by_class('ConservationScore.conservation_score');
        $mlss_id = $cs_mlsss->[0]->dbID if @$cs_mlsss;
    }

    my $output_id = {
        mlss_id         => $mlss->dbID,
        dump_mlss_id    => $mlss_id,            # Could be the mlss_id of conservation scores
        base_filename   => $filename,
        is_pairwise_aln => ($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment' ? 1 : 0),
        %$extra_params,
    };

    # mimic directory structure of FTP server
    my $aln_type = $output_id->{is_pairwise_aln} ? 'pairwise_alignments' : 'multiple_alignments';
    $output_id->{aln_type} = $aln_type;

    my $output_dir = $self->param_required('export_dir');
    if ($self->param('format') eq 'emf+maf') {
        $output_id->{format} = 'emf';
        $output_id->{run_emf2maf} = 1;

        foreach my $format ( 'emf', 'maf' ) {
            my $output_dir = "$output_dir/$format/ensembl-compara/$aln_type/$filename";
            # remove_tree($output_dir);
            make_path($output_dir);
        }
    } else {
        $output_id->{run_emf2maf} = 0;
        my $output_dir = $self->param_required('export_dir').'/'.$self->param('format')."/ensembl-compara/$aln_type/$filename";
        # remove_tree($output_dir);
        make_path($output_dir);
    }

    # Override autoflow and make sure the descendant jobs have all the
    # parameters
    $self->dataflow_output_id($output_id, 2);
}

1;
