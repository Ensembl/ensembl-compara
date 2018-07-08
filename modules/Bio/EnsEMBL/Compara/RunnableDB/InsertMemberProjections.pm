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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::InsertMemberProjections

=cut

=head1 SYNOPSIS

        # Translates and insert the projections for human and mouse
    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::InsertMemberProjections -source_species_names "['homo_sapiens', 'mus_musculus']" -compara_db mysql://...

=cut

=head1 DESCRIPTION

This RunnableDB converts the stable IDs found in the
seq_member_projection_stable_id table to member_ids that can be inserted in
the seq_member_projection table.

Since the stable IDs are transcript stable IDs and we only store the
translation stable IDs of the protein-coding genes, this RunnableDB needs
to access the core database to get a mapping of transcripts to
translations.

The only parameter is "source_species_names" which tells which species are
used for projections. This is used to limit the memory usage by only
loading the data for the relevant species.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::InsertMemberProjections;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::CopyData qw(bulk_insert_iterator);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $source_species_names = $self->param_required('source_species_names');

    # TranscriptAdaptor has fetch_all() and TranslationAdaptor has
    # fetch_all_by_Transcript_list() but the latter insists on fetching all
    # the exons for each each translation, fetching them 1 translation at a
    # time. As you imagine, this is a killer ...
    # Direct SQL is so much faster !
    my $sql = 'SELECT transcript.stable_id, translation.stable_id FROM transcript JOIN translation ON transcript.canonical_translation_id = translation.translation_id';

    # Mapping of stable_ids (transcripts and translations) to seq_member_ids
    my %stable_id_2_seq_member_id;
    foreach my $species_name (@$source_species_names) {
        # The GenomeDB
        my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_name_assembly($species_name)
            or die "Can't fetch the genome_db object (name=$species_name) from Compara";

        # The SeqMembers we have for this GenomeDB
        my $seq_members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_by_GenomeDB($genome_db);
        $stable_id_2_seq_member_id{ $_->stable_id } = $_->dbID for @$seq_members;
        $self->say_with_header(scalar(@$seq_members) . ' members for ' . $species_name);

        # The mapping transcript.stable_id -> translation.stable_id from the core database
        my $transcript_2_translation = $genome_db->db_adaptor->dbc->sql_helper->execute_into_hash( -SQL => $sql );
        while (my ($transcript_stable_id, $translation_stable_id) = each %{$transcript_2_translation}) {
            if ($stable_id_2_seq_member_id{$translation_stable_id}) {
                # If we have the translation, add the transcript
                $stable_id_2_seq_member_id{$transcript_stable_id} = $stable_id_2_seq_member_id{$translation_stable_id};
            }
        }
        $self->say_with_header(scalar(keys %$transcript_2_translation) . ' translations for ' . $species_name);
    }
    $self->say_with_header(scalar(keys %stable_id_2_seq_member_id) . ' stable_ids in the mapping');
    $self->param('stable_id_2_seq_member_id', \%stable_id_2_seq_member_id);
}


sub write_output {
    my $self = shift @_;
    my $stable_id_2_seq_member_id = $self->param('stable_id_2_seq_member_id');
    my $sql_select = 'SELECT target_seq_member_id, source_stable_id FROM seq_member_projection_stable_id';
    my $fetch_iterator = $self->compara_dba->dbc->sql_helper->execute( -SQL => $sql_select, -ITERATOR => 1 );
    my $data_iterator = $fetch_iterator->grep( sub { $stable_id_2_seq_member_id->{$_->[1]} } )->map( sub { [$_->[0], $stable_id_2_seq_member_id->{$_->[1]}] } );
    bulk_insert_iterator($self->compara_dba->dbc, 'seq_member_projection', $data_iterator, ['target_seq_member_id', 'source_seq_member_id'], 'REPLACE');
}


1;
