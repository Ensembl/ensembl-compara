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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory 

=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for BlastAndParsePAF. 
Supported keys:

   'genome_db_id' => <number>
       Genome_db id. Obligatory

   'step' => <number>
       How many sequences to write into the blast query file. Default 100

   'species_set_id' => <number> (optionnal)
       The species set on which we want to run blast for that genome_db_id
       Default: uses all the GenomeDBs

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::BlastFactory;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BlastFactory');

use Data::Dumper;

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'species_set_id'     => undef,
    };
}


sub fetch_input {
    my $self = shift @_;

    my $genome_db_id = $self->param_required('genome_db_id');

    my $species_set_id = $self->param('species_set_id');
    my $target_genome_dbs = $species_set_id ? $self->compara_dba->get_SpeciesSetAdaptor->fetch_by_dbID($species_set_id)->genome_dbs : $self->compara_dba->get_GenomeDBAdaptor->fetch_all;
    # Polyploids have no genes, and hence no blastp database
    $self->param('target_genome_dbs', [grep {not $_->is_polyploid} @$target_genome_dbs]);

    my $all_members = $self->compara_dba->get_SeqMemberAdaptor->_fetch_all_representative_for_blast_by_genome_db_id($genome_db_id);

    print "GDB ID: $genome_db_id\n";
    print "all_members: ";
    print scalar @{ $all_members };
    print "\n";

    $self->param('query_members', $all_members);
}


sub flow_blast_jobs {
    my $self = shift @_;
    my $ref_output_id = shift;

    my $genome_db_id = $self->param('genome_db_id');
    my @target_genome_db_ids = sort {$a <=> $b} (map {$_->dbID} @{$self->param('target_genome_dbs')});

    foreach my $target_genome_db_id (@target_genome_db_ids) {
        my $output_id = { %$ref_output_id };
        $output_id->{'genome_db_id'} = $genome_db_id;
        $output_id->{'target_genome_db_id'} = $target_genome_db_id;
        $self->dataflow_output_id($output_id, 2);
    }
}

1;
