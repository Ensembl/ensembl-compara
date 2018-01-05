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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::CreateChrJobs

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the species chromosomes. The jobs are split into $split_size chunks

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use POSIX qw(ceil);


sub write_output {
    my $self = shift @_;

    #Note this is using the database set in $self->param('compara_db').
    my $compara_dba = $self->compara_dba;

    #
    #Find chromosome names and numbers of genomic_align_blocks
    #
    my $sql = qq {
    SELECT
       name,
       count(*)
    FROM
       dnafrag,
       genomic_align
    WHERE 
       dnafrag.dnafrag_id = genomic_align.dnafrag_id 
    AND 
       genome_db_id = ? 
    AND 
       coord_system_name = ? 
    AND 
       method_link_species_set_id = ? 
    AND
       dnafrag_start <= length
    GROUP BY name};

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('genome_db_id'), 
		  $self->param('coord_system_name'),
		  $self->param('mlss_id'));
    my ($name, $total_blocks);
    $sth->bind_columns(\$name,\$total_blocks);

    my $tag = $self->param('coord_system_name') eq 'chromosome' ? 'chr' : '';

    my $split_size = $self->param('split_size');

    while (my $row = $sth->fetchrow_arrayref) {

        if (not $split_size) {
            my $output_ids = {
                region_name     => $tag.$name,
                filename_suffix => '',
                extra_args      => ['--seq_region', $name],
                num_blocks      => $total_blocks,
            };

            $self->dataflow_output_id($output_ids, 2);
            next;
        }

        my $num_chunks = ceil($total_blocks / $split_size);

	for (my $chunk = 1; $chunk <= $num_chunks; $chunk++) {

	    #Number of gabs in this chunk (used for healthcheck)
	    my $this_num_blocks = $split_size;
	    if ($chunk == $num_chunks) {
		$this_num_blocks = ($total_blocks - (($chunk-1)*$split_size));
	    }

	    #Write out cmd for DumpMultiAlign and a few other parameters 
	    #used in downstream analyses 
	    my $output_ids = {
                region_name     => $tag.$name,
                filename_suffix => "_$chunk",
                extra_args      => ['--seq_region', $name, '--chunk_num', $chunk],
                num_blocks      => $this_num_blocks,
            };
	    
	    $self->dataflow_output_id($output_ids, 2);
	}
    }
}

1;
