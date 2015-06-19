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

Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::ChrJobsFactory

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the species chromosomes. 

=head1 AUTHOR

ckong

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::ChrJobsFactory;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use POSIX qw(ceil);

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;
}

sub write_output {
    my $self = shift @_;

    my $output_ids;

    #Load registry and get compara database adaptor
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

    #Find chromosome names and numbers of genomic_align_blocks
    my $sql = qq {
    SELECT name, count(*)
    FROM  dnafrag, genomic_align
    WHERE dnafrag.dnafrag_id = genomic_align.dnafrag_id 
    AND   genome_db_id = ? 
    AND   coord_system_name = ? 
    AND   method_link_species_set_id = ? 
    GROUP BY name};

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('genome_db_id'), 
		  $self->param('coord_system_name'),
		  $self->param('mlss_id'));

    $compara_dba->dbc->reconnect_when_lost(1);

    my ($name, $total_blocks);
    $sth->bind_columns(\$name,\$total_blocks);

    my $chr_blocks; 
    my $tag;
    if ($self->param('coord_system_name') eq "chromosome") {
	$tag = "chr";
    }

    my $compara_url       = $self->param('compara_url');
    my $split_size        = 0;
    my $format            = $self->param('format');
    my $coord_system_name = $self->param('coord_system_name');

    if (defined($compara_url)) {
	#need to protect the @
	$compara_url =~ s/@/\\\\@/;
    }

    while (my $row = $sth->fetchrow_arrayref) {
	my $output_file = $self->param('filename') . "." . $tag . $name . "." . $self->param('format');

	my $dump_output_file = $output_file;

	#Write out cmd for DumpMultiAlign and a few other parameters 
	#used in downstream analyses 
	my $mlss_id    = $self->param('mlss_id');
	my $species    = $self->param('species');

	my $output_ids = "{\"mlss_id\"=> \"$mlss_id\", \"species\"=> \"$species\",\"coord_system\"=> \"$coord_system_name\", \"output_file\"=> \"$output_file\", \"extra_args\"=> \"--seq_region $name --chunk_num 1\", \"num_blocks\"=> 0, \"dumped_output_file\"=> \"$dump_output_file\", \"format\"=> \"$format\"}";
	    
        $self->dataflow_output_id($output_ids, 2);
    }

}

1;
