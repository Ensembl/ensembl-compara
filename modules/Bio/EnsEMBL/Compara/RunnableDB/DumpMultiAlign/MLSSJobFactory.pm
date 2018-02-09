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
        'species_priority'   => [ 'homo_sapiens', 'gallus_gallus', 'oryzias_latipes' ],
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
        $self->_test_mlss($mlss);
        return;
    }

    foreach my $ml_typ (split /[,:]/, $self->param_required('method_link_types')){
        # Get MethodLinkSpeciesSet Objects for required method_link_type
        my $mlss_listref = $mlssa->fetch_all_by_method_link_type($ml_typ);
        foreach my $mlss (@$mlss_listref) {
            next if ( defined $self->param('from_first_release') && $mlss->first_release < $self->param('from_first_release') );
            $self->_test_mlss($mlss);
        }
    }
}

sub _test_mlss {
    my ($self, $mlss) = @_;

    my $mlss_id     = $mlss->dbID();

    unless ($mlss->method->class =~ /^GenomicAlign/) {
        die sprintf("%s (%s) MLSSs cannot be dumped with this pipeline !\n", $mlss->method->type, $mlss->method->class);
    }
    if ($mlss->method->type =~ /^CACTUS_HAL/) {
        die "Cactus alignments cannot be dumped because they already exist as files\n";
    }

    if (($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment') or ($mlss->method->type eq 'EPO_LOW_COVERAGE')) {
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
    my $species_name      = $mlss->get_value_for_tag('reference_species');
    my $genome_db         = $genome_db_adaptor->fetch_by_name_assembly($species_name)
                             || $genome_db_adaptor->fetch_by_registry_name($species_name);
    $genome_db->db_adaptor || die "I don't know where the '$species_name' core database is. Have you defined the Registry ?\n";

    my $filename;
    if ($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment') {
        my ($non_ref_gdb) = grep {$_->dbID != $genome_db->dbID} @{$mlss->species_set->genome_dbs};
        $non_ref_gdb //= $genome_db;    # for self-alignments
        $filename = sprintf("%s.%s.vs.%s.%s.%s", $genome_db->name, $genome_db->assembly, $non_ref_gdb->name, $non_ref_gdb->assembly, lc $mlss->method->type);
    } else {
        $filename = $mlss->name;
    }
    $filename =~ s/[\W\s]+/_/g;
    $filename =~ s/_$//;

    if ($self->param('add_conservation_scores')) {
        foreach my $method (@{ $compara_dba->get_MethodAdaptor->fetch_all_by_class_pattern('ConservationScore.conservation_score') }) {
            my $cs_mlss = $mlss->adaptor->fetch_by_method_link_id_species_set_id($method->dbID, $mlss->species_set->dbID);
            if ($cs_mlss) {
                $mlss_id = $cs_mlss->dbID;
                last
            }
        }
    }

    my $output_dir = $self->param_required('export_dir').'/'.$filename;
    my $output_id = {
        mlss_id         => $mlss->dbID,
        dump_mlss_id    => $mlss_id,            # Could be the mlss_id of conservation scores
        species         => $species_name,
        genome_db_id    => $genome_db->dbID,
        base_filename   => $filename,
        is_pairwise_aln => ($mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment' ? 1 : 0),
    };

    remove_tree($output_dir);
    make_path($output_dir);

    if ($self->param('format') eq 'emf+maf') {
        $output_id->{format} = 'emf';
        $output_id->{run_emf2maf} = 1;
        remove_tree($output_dir.'.maf');
        make_path($output_dir.'.maf');
    } else {
        $output_id->{run_emf2maf} = 0;
    }

    # Override autoflow and make sure the descendant jobs have all the
    # parameters
    $self->dataflow_output_id($output_id, 2);
}

1;

