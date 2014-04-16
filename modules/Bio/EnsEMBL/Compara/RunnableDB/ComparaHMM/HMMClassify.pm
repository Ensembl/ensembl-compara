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


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClassify;

use strict;
use warnings;


use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my ($self) = @_;

    my $genome_db_id = $self->param_required('genome_db_id');
    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($genome_db_id);
    $self->param('genome_db', $genome_db);

    my $members = $self->compara_dba->get_SeqMemberAdaptor->fetch_all_canonical_by_GenomeDB($genome_db_id);

    my %unannotated_member_ids = ();
    my $sth = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_genes_missing_annot_by_genome_db_id($genome_db_id);
    $unannotated_member_ids{$_->[0]} = 1 for @{$sth->fetchall_arrayref};
    $sth->finish;
    $self->param('unannotated_member_ids', \%unannotated_member_ids);

    my @unannotated_members = grep {exists $unannotated_member_ids{$_->dbID}} @$members;
    $self->param('unannotated_members', \@unannotated_members);

    $self->param('all_hmm_annots', {});
}

sub add_hmm_annot {
    my ($self, $seq_id, $hmm_id, $eval) = @_;
    print STDERR "Found [$seq_id, $hmm_id, $eval]\n" if ($self->debug());
    if (exists $self->param('all_hmm_annots')->{$seq_id}) {
        if ($self->param('all_hmm_annots')->{$seq_id}->[1] < $eval) {
            print STDERR "Not registering it because the evalue is higher than the currently stored one: ", $self->param('all_hmm_annots')->{$seq_id}->[1], "\n" if $self->debug();
        }
    }
    $self->param('all_hmm_annots')->{$seq_id} = [$hmm_id, $eval];
}


sub write_output {
    my ($self) = @_;
    my $adaptor = $self->compara_dba->get_HMMAnnotAdaptor();
    my $all_hmm_annots = $self->param('all_hmm_annots');
        # Store into table 'hmm_annot'
    foreach my $seq_id (keys %$all_hmm_annots) {
        $adaptor->store_hmmclassify_result($seq_id, @{$all_hmm_annots->{$seq_id}});
    }
}



1;
