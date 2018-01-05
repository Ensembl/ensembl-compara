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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::CreateSuperJobs

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the species supercontigs.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use POSIX qw(ceil);

sub write_output {
    my $self = shift @_;

    #Note this is using the database set in $self->param('compara_db').
    my $compara_dba = $self->compara_dba;

    #
    #Find supercontigs and number of genomic_align_blocks
    #
    my $sql = "
    SELECT count(*) 
    FROM genomic_align 
    LEFT JOIN dnafrag 
    USING (dnafrag_id) 
    WHERE coord_system_name = ? 
    AND genome_db_id= ? 
    AND method_link_species_set_id=?";

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('coord_system_name'),$self->param('genome_db_id'), $self->param('mlss_id'));
    my ($total_blocks) = $sth->fetchrow_array;

    # exit if there is nothing to dump
    return unless $total_blocks;
    
    #Write out cmd for DumpMultiAlign and a few other parameters 
    #used in downstream analyses 
    
    my $output_ids = {
                     'region_name'        => '#coord_system_name#',
                     'filename_suffix'    => '*',   # We need the star because DumpMultiAlignment.pl adds _1 to the output file and can create more if there are lots of supercontigs (when split_size is set)
                     'num_blocks'         => $total_blocks,
                     'extra_args'         => [ '--coord_system', '#coord_system_name#' ],
                    };

    $self->dataflow_output_id($output_ids, 2);
}

1;
