=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CreateSubChunkedJobs

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module creates even smaller chunked jobs for running with analysis "ancestral_alleles_for_indels". This is optimise the running time and memory usage. 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CreateSubChunkedJobs;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;

}

sub write_output {
    my $self = shift @_;

    my $url = $self->param('url');
    my $seq_region = $self->param('seq_region');
    my $chunk_end = $self->param('seq_region_end');
    my $length = $self->param('seq_region_end') - $self->param('seq_region_start') + 1;
    my $sub_dir = "$seq_region/" . $self->param('seq_region_start') . "_" . $self->param('seq_region_end');
    my $sub_chunk_size = $self->param('sub_chunk_size');

    my $chunk = $self->param('seq_region_start');
    while ($chunk <= $chunk_end) {
        my $seq_region_start = $chunk;

        $chunk += $sub_chunk_size;
        my $seq_region_end = $chunk - 1;
        if ($seq_region_end > $chunk_end) {
            $seq_region_end = $chunk_end;
        }
        #Create ancestral_alleles_for_indels jobs
        my $output_ids = {'seq_region'=> $seq_region,
                          'seq_region_start' => $seq_region_start,
                          'seq_region_end' => $seq_region_end,
                          'sub_dir' => $sub_dir};
        
        $self->dataflow_output_id($output_ids, 2);
    }
}

1;
