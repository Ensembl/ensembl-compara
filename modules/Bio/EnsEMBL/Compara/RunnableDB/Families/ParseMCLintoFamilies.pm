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

package Bio::EnsEMBL::Compara::RunnableDB::Families::ParseMCLintoFamilies;

# RunnableDB to parse the MCL output and load the families

use strict;
use warnings;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Family;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {   # nothing to fetch here, just write_output()
}

sub run {   # nothing to run, just write_output()
}

sub write_output {
    my $self = shift @_;

    my $mlss_id         = $self->param_required('mlss_id');
    my $mcl_name        = $self->param_required('mcl_name');
    my $family_prefix   = $self->param('family_prefix') || 'ENSF';
    my $family_offset   = $self->param('family_offset') || 0;

    my $compara_dba     = $self->compara_dba();

    my $fa            = $compara_dba->get_FamilyAdaptor();
    my $sma           = $compara_dba->get_SeqMemberAdaptor();
    my $cluster_index = 1;

    open (my $mcl_fh, '<', $mcl_name) || die "could not open '$mcl_name' for reading: $!";
    while (my $line = <$mcl_fh>) {
        chomp $line;

        my @cluster_members = split(/\s+/, $line);

        if( (scalar(@cluster_members) == 0)
        or ((scalar(@cluster_members) == 1) and ($cluster_members[0] eq '0'))) {
            print STDERR "Skipping an empty cluster $cluster_index\n" if($self->debug);
            next;
        }

        print STDERR "Loading cluster $cluster_index..." if($self->debug);

        my $family_stable_id = sprintf ("$family_prefix%011d",$cluster_index + $family_offset);
        my $family = Bio::EnsEMBL::Compara::Family->new_fast({
            '_stable_id'                    => $family_stable_id,
            '_version'                      => 1,
            '_method_link_species_set_id'   => $mlss_id,
            '_description_score'            => 0,
        });

        foreach my $tab_idx (@cluster_members) {

            if( my $seq_member = $sma->fetch_all_by_sequence_id($tab_idx)->[0] ) {
                # A funny way to add members to a family.
                # You cannot do it without introducing a fake AlignedMember, it seems?
                #
                bless $seq_member, 'Bio::EnsEMBL::Compara::AlignedMember';
                $family->add_Member($seq_member);
            } else {
                warn "Could not fetch seq_member by sequence_id=$tab_idx";
            }
        }

        my $family_dbID = $fa->store($family);

        $cluster_index++;

        print STDERR "Done\n" if($self->debug);
    }
    close $mcl_fh;
}

1;
