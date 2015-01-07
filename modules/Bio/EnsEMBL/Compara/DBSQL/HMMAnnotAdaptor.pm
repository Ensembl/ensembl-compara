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

=head1 NAME

HMMAnnotAdaptor

=head1 SYNOPSIS

=head1 DESCRIPTION

=head1 AUTHOR

ChuangKee Ong

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut
package Bio::EnsEMBL::Compara::DBSQL::HMMAnnotAdaptor;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Utils::Exception qw(throw warning deprecate); ## All needed?

use DBI qw(:sql_types);
use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


sub fetch_all_hmm_annot {
    my ($self) = @_;

    my $sql = "SELECT * FROM hmm_annot";
    my $sth = $self->prepare($sql);

return $sth;
}


sub fetch_all_genes_missing_annot {
    my ($self) = @_;

    my $sql = "SELECT canonical_member_id FROM gene_member LEFT JOIN hmm_annot ON canonical_member_id = seq_member_id WHERE seq_member_id IS NULL";
    my $sth = $self->prepare($sql);
    $sth->execute();

    return $sth;
}


sub fetch_all_genes_missing_annot_by_range {
    my ($self, $start_member_id, $end_member_id) = @_;

    my $sql = "SELECT canonical_member_id FROM gene_member LEFT JOIN hmm_annot ON canonical_member_id = seq_member_id WHERE seq_member_id IS NULL AND canonical_member_id BETWEEN ? AND ?";
    my $sth = $self->prepare($sql);
    $sth->execute($start_member_id, $end_member_id);

    return $sth;
}

sub fetch_all_seqs_missing_annot {
    my ($self) = @_;

    my $sql = "SELECT seq_member_id FROM seq_member LEFT JOIN hmm_annot USING (seq_member_id) WHERE hmm_annot.seq_member_id IS NULL";
    my $sth = $self->prepare($sql);
    $sth->execute();

    return $sth;
}


sub fetch_all_seqs_missing_annot_by_range {
    my ($self, $start_member_id, $end_member_id) = @_;

    my $sql = "SELECT seq_member_id FROM seq_member LEFT JOIN hmm_annot USING (seq_member_id) WHERE hmm_annot.seq_member_id IS NULL AND seq_member.seq_member_id BETWEEN ? AND ?";
    my $sth = $self->prepare($sql);
    $sth->execute($start_member_id, $end_member_id);

    return $sth;
}


sub store_hmmclassify_result {
    my ($self, $seq_member_id, $model_id, $evalue) = @_;

    my $sql = "INSERT INTO hmm_annot(seq_member_id, model_id, evalue) VALUES (?,?,?)";
    my $sth = $self->prepare($sql);
    $sth->execute($seq_member_id, $model_id, $evalue);
    $sth->finish();
}

1;
