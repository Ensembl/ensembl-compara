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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::InitInputID

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB prepares parameters that should be known to all
the subsequent jobs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitInputID;

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

    my $output_dir = $self->param_required('export_dir').'/'.$self->param('filename');
    my $output_ids = {
        mlss_id         => $self->param('mlss_id'),
        genome_db_id    => $self->param('genome_db_id'),
        base_filename   => $self->param('filename'),
        is_pairwise_aln => $self->param('is_pairwise_alignment'),
    };

    make_path($output_dir);

    if ($self->param('format') eq 'emf+maf') {
        $output_ids->{format} = 'emf';
        $output_ids->{run_emf2maf} = 1;
        make_path($output_dir.'_maf');
    } else {
        $output_ids->{run_emf2maf} = 0;
    }

    # Override autoflow and make sure the descendant jobs have all the
    # parameters
    $self->dataflow_output_id($output_ids, 1);
}

1;
