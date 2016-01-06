=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::InitJobs.pm

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module creates 3 jobs: 1) gabs on chromosomes 2) gabs on 
supercontigs 3) gabs without $species (others)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs;

use strict;
use warnings;

use File::Path qw(make_path);

use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    my $file_prefix = "Compara";

    #Note this is using the database set in $self->param('compara_db') rather than the underlying eHive database.
    my $compara_dba       = $self->compara_dba;
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my $genome_db         = $genome_db_adaptor->fetch_by_name_assembly($self->param_required('species'))
                             || $genome_db_adaptor->fetch_by_registry_name($self->param('species'));
    $genome_db->db_adaptor || die "I don't know where the ".$self->param('species')." core database is. Have you defined the Registry ?\n";
    my $coord_systems     = $genome_db->db_adaptor->get_CoordSystemAdaptor->fetch_all_by_attrib('default_version');;

    my $sql = "
    SELECT DISTINCT coord_system_name
    FROM genomic_align JOIN dnafrag USING (dnafrag_id)
    WHERE genome_db_id= ? AND method_link_species_set_id=?";

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($genome_db->dbID, $self->param_required('mlss_id'));
    my %coord_systems_in_aln = map {$_->[0] => 1} @{$sth->fetchall_arrayref};

    my @coord_system_names_by_rank = map {$_->name} (sort {$a->rank <=> $b->rank} (grep {$coord_systems_in_aln{$_->name}} @$coord_systems));

    $self->param('coord_systems', \@coord_system_names_by_rank);
    $self->param('genome_db_id', $genome_db->dbID);

    #
    #If want to dump alignments and scores, need to find the alignment mlss
    #and store in param('mlss_id')
    #
    my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
    my $mlss         = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
    if ($mlss->method->type eq "GERP_CONSERVATION_SCORE") {
      $self->param('mlss_id', $mlss->get_value_for_tag('msa_mlss_id'));
    }

    $self->param('is_pairwise_alignment', $mlss->method->class eq 'GenomicAlignBlock.pairwise_alignment' ? 1 : 0);

    $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
    my $filename = $mlss->name;
    $filename =~ s/[\W\s]+/_/g;
    $filename =~ s/_$//;
    $filename = $file_prefix . "." . $filename;
    $self->param('filename', $filename);
}


sub write_output {
    my $self = shift @_;

    #
    #Pass on input_id and add on new parameters: multi-align mlss_id, filename
    #

    my $output_dir = $self->param_required('export_dir').'/'.$self->param('filename');
    my $output_ids = {
        mlss_id         => $self->param('mlss_id'),
        genome_db_id    => $self->param('genome_db_id'),
        base_filename   => $self->param('filename'),
        output_dir      => '#export_dir#/#base_filename#',
    };

    if ($self->param_required('split_mode') eq 'random') {

        # In this mode, we don't care about the chromsome names and
        # coordinate systems, we let createOtherJobs bin the alignment
        # blocks into chunks
        $self->dataflow_output_id($output_ids, 4);

    } elsif ($self->param_required('format') eq 'emf2maf') {

        # In this mode, we read the EMF files from one directory, and
        # convert them to MAF in another one
        die "The EMF directory '$output_dir' does not exist.\n" unless -d $output_dir;
        die "The EMF directory '$output_dir' is not complete.\n" unless -e $output_dir.'/README.'.$self->param('filename');

        # Fix the format name for dumpMultiAlign
        $output_ids->{format}            = 'maf';
        # output_dir is another directory alongside #base_filename#
        $output_ids->{output_dir}        = '#export_dir#/#base_filename#_maf',
        $output_dir .= '_maf';

        # Flow into the emf2maf branch
        $self->dataflow_output_id($output_ids, 6);

    } else {

        my @all_cs = @{$self->param('coord_systems')};
        #Set up chromosome job
        my $cs = shift @all_cs;
        $self->dataflow_output_id( {%$output_ids, 'coord_system_name' => $cs}, 2) if $cs;

        #Set up supercontig job
        foreach my $other_cs (@all_cs) {
            $self->dataflow_output_id( {%$output_ids, 'coord_system_name' => $other_cs}, 3);
        }

        #Set up other job
        $self->dataflow_output_id($output_ids, 4) unless $self->param('is_pairwise_alignment');

        # In case there is something connected there: a job to dump all the
        # blocks in 1 file
        $self->dataflow_output_id( {%$output_ids, 'region_name' => 'all', 'extra_args' => []}, 5);

    }

    make_path($output_dir);

    # Override autoflow and make sure the descendant jobs have all the
    # parameters
    $self->dataflow_output_id($output_ids, 1);
}

1;
