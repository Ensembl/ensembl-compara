=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
on the species supercontigs. The jobs are split into $split_size chunks

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use POSIX qw(ceil);

sub fetch_input {
    my $self = shift;
}


sub run {
    my $self = shift;
}

sub write_output {
    my $self = shift @_;

    #
    #Load registry and get compara database adaptor
    #
    if ($self->param('reg_conf')) {
	Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'),1);
    } elsif ($self->param('db_url')) {
	my $db_urls = $self->param('db_url');
	foreach my $db_url (@$db_urls) {
	    Bio::EnsEMBL::Registry->load_registry_from_url($db_url);
	}
    } else {
	Bio::EnsEMBL::Registry->load_all();
    }

    #Note this is using the database set in $self->param('compara_db') rather than the underlying compara database.
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
    
    my $tag = $self->param('coord_system_name');
    #my $output_file = $self->param('output_dir') ."/" . $self->param('filename') . "." . $tag . "." . $self->param('format');
    my $output_file = $self->param('filename') . "." . $tag . "." . $self->param('format');
    $output_file=~s/[\(\)]+//g;
    $output_file=~s/-/_/g;
    
    my $format = $self->param('format');
    my $coord_system_name = $self->param('coord_system_name');
    #This doesn't work because DumpMultiAlignment adds _1 to the output file and can create more if there are lots of supercontigs.
    #Since I create only one job, the compress will only start when all the chunks have been produced (if more than one) so I can use "*"
    #my $this_suffix = "." . $format;
    my $this_suffix = "*" . "." . $format;
    my $dump_output_file = $output_file;
    $dump_output_file =~ s/\.$format/$this_suffix/;
	
    #Write out cmd for DumpMultiAlign and a few other parameters 
    #used in downstream analyses 
    #$output_ids = "{\"coord_system\"=> \"$coord_system_name\", \"output_file\"=> \"$output_file\", \"num_blocks\"=> $total_blocks, \"dumped_output_file\"=> \"$dump_output_file\", \"format\"=> \"$format\"}";
    
    my $extra_args = ""; #Need to put something here
    my $output_ids = {
                     'coord_system'       => $coord_system_name,
                     'output_file'        => $output_file,
                     'num_blocks'         => $total_blocks,
                     'dumped_output_file' => $dump_output_file,
                     'format'             => $format,
                     'extra_args'         => $extra_args,
                    };

    $self->dataflow_output_id($output_ids, 2);
}

1;
