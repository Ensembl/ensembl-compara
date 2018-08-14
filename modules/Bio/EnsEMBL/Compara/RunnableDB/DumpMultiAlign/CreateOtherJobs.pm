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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::CreateOtherJobs

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the chromosomes which do not contain species. The jobs are split into 
$split_size chunks

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateOtherJobs;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub skip_genomic_align_block_ids {
    my $self = shift @_;

    my $sql = 'SELECT DISTINCT genomic_align_block_id FROM genomic_align JOIN dnafrag USING (dnafrag_id) WHERE method_link_species_set_id = ? AND genome_db_id = ?';

    my $gab_ids_to_skip = $self->compara_dba->dbc->sql_helper->execute_simple(
        -SQL => $sql,
        -PARAMS => [$self->param_required('mlss_id'), $self->param_required('genome_db_id')],
    );

    my %gab_ids_to_skip = map {$_ => 1} @$gab_ids_to_skip;

    return [grep {!$gab_ids_to_skip{$_}} @{$self->all_genomic_align_block_ids}];
}


sub all_genomic_align_block_ids {
    my $self = shift @_;

    my $ancestral_gdb = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly('ancestral_sequences');
    my $sql = 'SELECT DISTINCT genomic_align_block_id FROM genomic_align JOIN dnafrag USING (dnafrag_id) WHERE method_link_species_set_id = ? AND genome_db_id != ?';

    return $self->compara_dba->dbc->sql_helper->execute_simple(
        -SQL => $sql,
        -PARAMS => [$self->param_required('mlss_id'), $ancestral_gdb->dbID],
    );
}


sub write_output {
    my $self = shift @_;

    my $gab_ids;
    my $region_name;

    unless ($self->param('do_all_blocks')) {
        # Here we select the blocks that don't contain $genome_db
        $gab_ids = $self->skip_genomic_align_block_ids();
        $region_name = 'other';
    } else {
        # In this mode, we simply take all the blocks
        $gab_ids = $self->all_genomic_align_block_ids();
        $region_name = 'all';
    }

    my $split_size = $self->param('split_size');
    my $gab_num = 1;
    my $start_gab_id ;
    my $end_gab_id;
    my $chunk = 1;
    
    #Create a table (other_gab) to store the genomic_align_block_ids
    my $sql_cmd = "INSERT IGNORE INTO other_gab (genomic_align_block_id) VALUES (?)";
    my $dump_sth = $self->data_dbc->prepare($sql_cmd);

    foreach my $gab_id (sort {$a <=> $b} @$gab_ids) {
	$dump_sth->execute($gab_id);

	if (!defined $start_gab_id) {
	    $start_gab_id = $gab_id;
	}

        if ($split_size == 0) {
            if ($gab_num == @$gab_ids) {
                my $output_id = {
                    'region_name'           =>  $region_name,
                    'start'                 =>  $start_gab_id,
                    'end'                   =>  $gab_id,
                    'filename_suffix'       =>  '',
                    'extra_args'            =>  [],
                    'num_blocks'            =>  $gab_num,
                };

                #print "skip $output_id\n";
                $self->dataflow_output_id($output_id, 2);
            }

	#Create jobs after each $split_size gabs
        } elsif ($gab_num % $split_size == 0 || $gab_num == @$gab_ids) {

	    $end_gab_id = $gab_id;

	    my $this_num_blocks = $split_size;
	    if ($gab_num == @$gab_ids) {
		$this_num_blocks = (@$gab_ids % $split_size);
	    }

	    #Write out cmd from DumpMultiAlign
	    #Used to create a file of genomic_align_block_ids to pass to
	    #DumpMultiAlign
	    my $output_id = {
                             'region_name'           =>  $region_name,
                             'start'                 =>  $start_gab_id,
                             'end'                   =>  $end_gab_id,
                             'filename_suffix'       =>  "_$chunk",
                             'extra_args'            =>  ['--chunk_num', $chunk],
                             'num_blocks'            =>  $this_num_blocks,
                            };

	    #print "skip $output_id\n";
	    $self->dataflow_output_id($output_id, 2);
	    undef($start_gab_id);
	    $chunk++;
	}
	$gab_num++;
    }
    $dump_sth->finish();
}


1;
