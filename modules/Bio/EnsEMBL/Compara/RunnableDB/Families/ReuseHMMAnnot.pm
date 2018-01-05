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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Families::ReuseHMMAnnot

=head1 DESCRIPTION

Module to copy all the Uniprot HMM annotations from a previous
Compara database to the current one.

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::ReuseHMMAnnot;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift;

    $self->complete_early('reuse_db not defined, nothing to copy') unless $self->param('reuse_db');
    my $reuse_dba = $self->get_cached_compara_dba('reuse_db');
    $self->param('reuse_dba', $reuse_dba);
}

sub run {
    my $self = shift;

    # Be very careful ! The order of the columns here must match the placeholders below
    my $sql_fetch = 'SELECT model_id, evalue, stable_id, md5sum FROM seq_member JOIN sequence USING (sequence_id) JOIN hmm_annot USING (seq_member_id) WHERE source_name IN ("Uniprot/SPTREMBL","Uniprot/SWISSPROT")';
    my $sth_fetch = $self->param('reuse_dba')->dbc->prepare( $sql_fetch, { 'mysql_use_result' => 1 } );

    my $sql_write = 'INSERT IGNORE INTO hmm_annot (seq_member_id, model_id, evalue) SELECT seq_member_id, ?, ? FROM seq_member JOIN sequence USING (sequence_id) WHERE stable_id = ? AND md5sum = ?';
    my $sth_write = $self->compara_dba()->dbc->prepare( $sql_write );

    $sth_fetch->execute;
    while (my $row = $sth_fetch->fetch) {
        my $rc = $sth_write->execute(@$row);
        unless ($rc) {
            warn "Aborting the copy";
            last;
        }
    }
    $sth_fetch->finish;
    $sth_write->finish;
}

1;

