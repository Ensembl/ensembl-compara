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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassifyCurated

=head1 DESCRIPTION


=head1 SYNOPSIS


=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassifyCurated;

use strict;
use warnings;

use Time::HiRes qw/time gettimeofday tv_interval/;
use Data::Dumper;

use Bio::EnsEMBL::Compara::MemberSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::HMMClassify');


=head2 run

    Title   :   run
    Usage   :   $self->run
    Function:   runs hmmbuild
    Returns :   none
    Args    :   none

=cut

sub run {
    my ($self) = @_;

    $self->load_curated_annotations;
}


##########################################
#
# internal methods
#
##########################################



sub load_curated_annotations {
    my ($self) = @_;

    my $sth  = $self->compara_dba->get_HMMAnnotAdaptor->fetch_all_hmm_curated_annot();
    my %curated_annot = ();
    while (my $res = $sth->fetchrow_arrayref){
        # seq_member_stable_id  model_id  library_version  annot_date  reason
        $curated_annot{$res->[0]} = $res->[1];
    }

    foreach my $member (@{$self->param('unannotated_members')}) {
        if (exists $curated_annot{$member->stable_id}) {
            $self->add_hmm_annot($member->dbID, $curated_annot{$member->stable_id}, undef);
        }
    }
}

1;
