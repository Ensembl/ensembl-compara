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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Registry;

sub fetch_input {
    my $self = shift;

    my $file_prefix      = "Compara";
    my $reg              = "Bio::EnsEMBL::Registry";
    my $method_link_type = $self->param('method_link_type');
 
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
    } # By default, we expect the genome_dbs to have a locator

    #Note this is using the database set in $self->param('compara_db') rather than the underlying compara database.
    my $compara_dba       = $self->compara_dba;
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my $genome_db         = $genome_db_adaptor->fetch_by_registry_name($self->param('species'));
    my $coord_systems     = $genome_db->db_adaptor->get_CoordSystemAdaptor->fetch_all_by_attrib('default_version');;
    my @coord_system_names_by_rank = map {$_->name} (sort {$a->rank <=> $b->rank} @$coord_systems);

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

    $mlss          = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
    my $genome_dbs = $mlss->species_set_obj->genome_dbs();
    my @filenames;

    foreach my $gdb (@$genome_dbs){
        push @filenames, $gdb->name().".".$gdb->assembly(); 
    }
    
    my $filename = join '-',@filenames;
    $filename = $file_prefix . "." . $filename . "_" . $method_link_type;
    $self->param('filename', $filename);
}


sub write_output {
    my $self = shift @_;

    #
    #Pass on input_id and add on new parameters: multi-align mlss_id, filename,
    #emf2maf
    #
    #my $output_ids = $self->input_id;
    my $output_ids;
    my $extra_args = "\"mlss_id\" => \"". $self->param('mlss_id') . "\"";
    $extra_args .= ",\"genome_db_id\" => \"". $self->param('genome_db_id') . "\"";
    $extra_args .= ",\"filename\" => \"". $self->param('filename') ."\"";
    $extra_args .= ",\"species\" => \"". $self->param('species') . "\"";
    $extra_args .= ",\"output_dir\" => \"". $self->param('output_dir') ."\"";

    $output_ids = "{$extra_args}";

    my $out_file = $self->param('filename');
    $out_file=~s/[\(\)]+//g;

    # If there were no jobs for the output channel 1, hive will invoke
    # autoflow by default. This will mess up the pipeline and must be
    # prevented here.
    $self->input_job->autoflow(0);

    #Set up chromosome/supercontig/other job
    $self->dataflow_output_id($output_ids, 2);
    $self->dataflow_output_id({'out_file' => $out_file, 'output_dir' => $self->param_required('output_dir')}, 1);

}

1;
