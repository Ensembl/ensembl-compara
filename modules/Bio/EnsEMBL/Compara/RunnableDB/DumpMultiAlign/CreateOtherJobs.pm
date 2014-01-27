=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
    my $reg = "Bio::EnsEMBL::Registry";

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

    my $tag = "other";

    my $output_file = $self->param('filename') . "." . $tag . "." . $self->param('format');

    #Convert eg human to Homo sapiens
    #my $species_name = $reg->get_adaptor($self->param('species'), "core", "MetaContainer")->get_production_name;

    my $mlss_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;

    my $genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('species'));
    my $species_name = $genome_db->name;

    my $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));

    #
    #Find genomic_align_blocks which do not contain $self->param('species')
    #
    my $skip_genomic_align_blocks = $gab_adaptor->
      fetch_all_by_MethodLinkSpeciesSet($mlss);
    for (my $i=0; $i<@$skip_genomic_align_blocks; $i++) {
	my $has_skip = 0;
	foreach my $this_genomic_align (@{$skip_genomic_align_blocks->[$i]->get_all_GenomicAligns()}) {
	    if (($this_genomic_align->genome_db->name eq $species_name) or
		($this_genomic_align->genome_db->name eq "ancestral_sequences")) {
		$has_skip = 1;
		last;
	    }
	}
	if ($has_skip) {
	    my $this_genomic_align_block = splice(@$skip_genomic_align_blocks, $i, 1);
	    $i--;
	    $this_genomic_align_block = undef;
	}
    }
    my $split_size = $self->param('split_size');
    my $format = $self->param('format');
    my $species = $self->param('species');

    my $gab_num = 1;
    my $start_gab_id ;
    my $end_gab_id;
    my $chunk = 1;

    
    #
    #Create a table (other_gab) to store the genomic_align_block_ids of those
    #blocks which do not contain $self->param('species')
    #
    foreach my $gab (sort {$a->dbID <=> $b->dbID} @$skip_genomic_align_blocks) {
	my $sql_cmd = "INSERT INTO other_gab (genomic_align_block_id) VALUES (?)";
	my $dump_sth = $self->db->dbc->prepare($sql_cmd);
	$dump_sth->execute($gab->dbID);
	$dump_sth->finish();

	if (!defined $start_gab_id) {
	    $start_gab_id = $gab->dbID;
	}

	#Create jobs after each $split_size gabs
	if ($gab_num % $split_size == 0 || 
	    $gab_num == @$skip_genomic_align_blocks) {

	    $end_gab_id = $gab->dbID;

	    my $this_num_blocks = $split_size;
	    if ($gab_num == @$skip_genomic_align_blocks) {
		$this_num_blocks = (@$skip_genomic_align_blocks % $split_size);
	    }

	    my $this_suffix = "_" . $chunk . "." . $format;
	    my $dump_output_file = $output_file;
	    $dump_output_file =~ s/\.$format/$this_suffix/;

            my $coord_system = ""; #Needs to be set to something to avoid errors in DumMultiAlign

	    #Write out cmd from DumpMultiAlign
	    #Used to create a file of genomic_align_block_ids to pass to
	    #DumpMultiAlign
	    my $output_id = {
                             'start'                 =>  $start_gab_id,
                             'end'                   =>  $end_gab_id,
                             'output_file'           =>  $output_file,
                             'extra_args'            =>  " --skip_species $species --chunk_num $chunk",
                             'num_blocks'            =>  $this_num_blocks,
                             'dumped_output_file'    =>  $dump_output_file,
                             'coord_system'          =>  $coord_system,
                            };

	    #print "skip $output_id\n";
	    $self->dataflow_output_id($output_id, 2);
	    undef($start_gab_id);
	    $chunk++;
	}
	$gab_num++;
    }
}


1;
