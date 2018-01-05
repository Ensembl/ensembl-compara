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


sub fetch_input {
    my $self = shift;

    #Note this is using the database set in $self->param('compara_db') rather than the underlying eHive database.
    my $genome_db         = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param_required('genome_db_id'));
    my $coord_systems     = $genome_db->db_adaptor->get_CoordSystemAdaptor->fetch_all_by_attrib('default_version');;

    my $sql = "
    SELECT DISTINCT coord_system_name
    FROM genomic_align JOIN dnafrag USING (dnafrag_id)
    WHERE genome_db_id= ? AND method_link_species_set_id=?";

    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($genome_db->dbID, $self->param_required('mlss_id'));
    my %coord_systems_in_aln = map {$_->[0] => 1} @{$sth->fetchall_arrayref};

    my @coord_system_names_by_rank = map {$_->name} (sort {$a->rank <=> $b->rank} (grep {$coord_systems_in_aln{$_->name}} @$coord_systems));

    $self->param('coord_systems', \@coord_system_names_by_rank);

}


sub write_output {
    my $self = shift @_;

        my @all_cs = @{$self->param('coord_systems')};
        #Set up chromosome job
        my $cs = shift @all_cs;
        $self->dataflow_output_id( {'coord_system_name' => $cs}, 2) if $cs;

        #Set up supercontig job
        foreach my $other_cs (@all_cs) {
            $self->dataflow_output_id( {'coord_system_name' => $other_cs}, 3);
        }

        #Set up other job
        $self->dataflow_output_id(undef, 4) unless $self->param('is_pairwise_aln');
}

1;
