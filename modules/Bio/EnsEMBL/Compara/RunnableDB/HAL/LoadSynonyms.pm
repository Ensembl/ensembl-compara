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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my( $self) = @_;

    $self->load_registry($self->param_required('registry_conf_file'));

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adaptor->fetch_by_dbID($self->param_required('mlss_id'));
    $self->param('mlss', $mlss);

    my $master_dba = $self->get_cached_compara_dba('master_db');
    my $genome_db_adaptor = $master_dba->get_GenomeDBAdaptor;
    my $genome_db = $genome_db_adaptor->fetch_by_dbID( $self->param_required('genome_db_id') );

    my $map_tag = $mlss->get_value_for_tag('HAL_mapping');
    my $species_map = eval $map_tag;     # read species name mapping hash from mlss_tag

    my $hal_adaptor = Bio::EnsEMBL::Compara::HAL::HALXS::HALAdaptor->new($mlss->url);
    my @chrom_list = $hal_adaptor->seqs_in_genome( $species_map->{ $genome_db->dbID } );

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

    # We don't have the MT chromosome, so we allow 1 missing DnaFrag
    if ($n_missing > 1) {
        die "Too many DnaFrags could not be found !";
    }

    $self->dataflow_output_id(\@names, 2);
}


1;
