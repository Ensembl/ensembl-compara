=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::FixNonCodingMembers

=head1 DESCRIPTION

This RunnableDB is a variant of LoadMembers that will focus on non-coding genes and update
the set of gene_members (adding new ones, and removing the ones that are not current any more).

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FixNonCodingMembers;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::LoadMembers');


### Let LoadMembers do the heavy-lifting, and then setup the structure to
### track the genes scheduled for removal

sub fetch_input {
    my $self = shift @_;

    $self->SUPER::fetch_input(@_);

    # Make it clear we don't support coding genes
    $self->param('store_coding', 0);

    # Get the list of members that are currently in the database
    my %members_to_match = map {$_->stable_id => $_}
                           grep {$_->biotype_group ne 'coding'}
                           @{$self->compara_dba->get_GeneMemberAdaptor->fetch_all_by_GenomeDB($self->param('genome_db'))};
    $self->param('members_to_match', \%members_to_match);
}


sub run {
    my $self = shift @_;

    $self->SUPER::run(@_);

    # Delete the members that were not found in the core database
    foreach my $gene_member (values %{$self->param('members_to_match')}) {
        $gene_member->adaptor->delete($gene_member);
    }
}


### Override the store methods to also update the biotype and mark the
### genes as seen

sub store_ncrna_gene {
    my $self = shift @_;

    $self->SUPER::store_ncrna_gene(@_);

    my $gene = $_[0];
    $self->update_biotype_group($gene);
    $self->mark_gene_as_seen($gene);
}


sub store_gene_generic {
    my $self = shift @_;

    $self->SUPER::store_gene_generic(@_);

    my $gene = $_[0];
    $self->update_biotype_group($gene);
    $self->mark_gene_as_seen($gene);
}


### Helper methods

sub mark_gene_as_seen {
    my $self = shift;
    my $gene = shift;
    delete $self->param('members_to_match')->{$gene->stable_id};
}

sub update_biotype_group {
    my $self = shift;
    my $gene = shift;
    # Some non-coding genes have a new biotype_group, e.g. mnoncoding -> lnoncoding
    $self->compara_dba->dbc->do('UPDATE gene_member SET biotype_group = ? WHERE stable_id = ?', undef, lc $gene->get_Biotype->biotype_group, $gene->stable_id);
}

1;
