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

=head2 fetch_by_ensembl_id

=cut 
sub fetch_by_ensembl_id_PTHR {
    my ($self, $ensembl_id) = @_;

    throw ("ensembl_id is undefined") unless (defined $ensembl_id);

    my $sql = "SELECT panther_family_id FROM panther_annot_PTHR WHERE ensembl_id=?";
    my $sth = $self->prepare($sql);

    $sth->execute($ensembl_id);
    my $res = $sth->fetchrow_arrayref;

return $res;
}

sub fetch_by_ensembl_id_SF {
    my ($self, $ensembl_id) = @_;

    throw ("ensembl_id is undefined") unless (defined $ensembl_id);
   
    my $sql = "SELECT panther_family_id FROM panther_annot_SF WHERE ensembl_id=?"; 
    my $sth = $self->prepare($sql);

    $sth->execute($ensembl_id);
    my $res = $sth->fetchrow_arrayref;

return $res;
}

sub fetch_all_hmm_annot {
    my ($self) = @_;

    my $sql = "SELECT * FROM hmm_annot";
    my $sth = $self->prepare($sql);

return $sth;
}

sub store_hmmclassify_result {
    my ($self, $member_id, $model_id, $evalue) = @_;

    my $sql = "INSERT INTO hmm_annot(member_id, model_id, evalue) VALUES (?,?,?)";
    my $sth = $self->prepare($sql);

    $sth->execute($member_id, $model_id, $evalue);

return;
}

1;
