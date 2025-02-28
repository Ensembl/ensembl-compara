=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSynonyms

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HAL::LoadSynonyms;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor;
use Bio::EnsEMBL::Compara::HAL::UCSCMapping;
use Bio::EnsEMBL::Hive::Utils qw(destringify);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults()},

        'n_missing_dnafrags' => 0,
    }
}


sub fetch_input {
    my( $self) = @_;

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($self->param_required('mlss_id'));

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $genome_db_adaptor = $master_dba->get_GenomeDBAdaptor;
    my $genome_db = $genome_db_adaptor->fetch_by_dbID( $self->param_required('genome_db_id') );

    my $species_map = destringify($mlss->get_value_for_tag('HAL_mapping', '{}'));

    my @hal_genome_dbs;
    if (exists $species_map->{ $genome_db->dbID }) {
        push(@hal_genome_dbs, $genome_db);
    }
    if ($genome_db->is_polyploid()) {
        my @hal_comp_genome_dbs = grep { exists $species_map->{ $_->dbID } } @{$genome_db->component_genome_dbs()};
        push(@hal_genome_dbs, @hal_comp_genome_dbs);
    }

    my $hal_adaptor = Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor->new($mlss->url);
    my %chrom_name_set;
    foreach my $hal_genome_db (@hal_genome_dbs) {
        foreach my $chrom_name ($hal_adaptor->seqs_in_genome($species_map->{ $hal_genome_db->dbID })) {
            $chrom_name_set{$chrom_name} = 1;
        }
    }
    my @chrom_list = sort keys %chrom_name_set;

    my $existing_synonyms = $Bio::EnsEMBL::Compara::HAL::UCSCMapping::u2e_mappings->{$genome_db->dbID} || {};

    my @names;
    my $n_missing = 0;
    foreach my $chr_name (@chrom_list) {
        if ($existing_synonyms->{$chr_name}) {
            push @names, { 'name' => $existing_synonyms->{$chr_name}, 'synonym' => $chr_name } if $existing_synonyms->{$chr_name} ne $chr_name;
            next;
        }
        my $d = $master_dba->get_DnaFragAdaptor->fetch_by_GenomeDB_and_synonym($genome_db, $chr_name);
        if ($d) {
            push @names, { 'name' => $d->name, 'synonym' => $chr_name } if $d->name ne $chr_name;
        } else {
            $n_missing++;
            $self->warning("Cannot find a DnaFrag for '$chr_name'\n");
        }
    }

    # We don't always have all the chromosomes, so we allow for a configurable number of missing DnaFrags.
    if ($n_missing > $self->param('n_missing_dnafrags')) {
        $self->input_job->transient_error(0);
        die "Too many DnaFrags ($n_missing) could not be found !";
    }

    $self->dataflow_output_id(\@names, 2);
}


1;
