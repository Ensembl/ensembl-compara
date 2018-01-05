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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::Families::HMMClusterize

=cut

=head1 SYNOPSIS

Blah

=cut

=head1 DESCRIPTION

Blah

=cut

=head1 CONTACT

  Please email comments or questions to the public Ensembl developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at <helpdesk@ensembl.org>.

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::HMMClusterize;

use strict;
use warnings;
use Time::HiRes qw(time gettimeofday tv_interval);
use Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::StoreClusters;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ComparaHMM::HMMClusterize');



sub write_output {
    my $self = shift @_;
    $self->store_families($self->param('allclusters'));
}




##########################################
#
# internal methods
#
##########################################


sub store_families {
    my ($self, $allclusters) = @_;

    my $compara_dba     = $self->compara_dba();
    my $method_link_species_set_adaptor = $compara_dba->get_MethodLinkSpeciesSetAdaptor;

    # make sure we have the correct $mlss:
    my $mlss = $method_link_species_set_adaptor->fetch_by_dbID($self->param_required('mlss_id'));

    my $fa            = $compara_dba->get_FamilyAdaptor();
    my $ma            = $compara_dba->get_SeqMemberAdaptor();

    my @cluster_list = sort {scalar(@{$allclusters->{$b}->{members}}) <=> scalar(@{$allclusters->{$a}->{members}})} keys %$allclusters;
    foreach my $model_name (@cluster_list) {

        my $cluster_members = $allclusters->{$model_name}->{members};

        if (scalar(@$cluster_members) == 0) {
            print STDERR "Skipping an empty cluster $model_name\n" if($self->debug);
            next;
        }

        print STDERR "Loading cluster $model_name..." if($self->debug);

        my $family = Bio::EnsEMBL::Compara::Family->new_fast({
            '_stable_id'                    => $model_name,
            '_version'                      => 1,
            '_method_link_species_set'      => $mlss,
            '_method_link_species_set_id'   => $mlss->dbID,
            '_description_score'            => 0,
        });

        my $members = $ma->fetch_all_by_dbID_list($cluster_members);
        foreach my $member (@{$members}) {

            # A funny way to add members to a family.
            # You cannot do it without introducing a fake AlignedMember, it seems?
            #
            bless $member, 'Bio::EnsEMBL::Compara::AlignedMember';
            $family->add_Member($member);
        }

        my $family_dbID = $fa->store($family);

        print STDERR "Done\n" if($self->debug);
    }
}
1;
