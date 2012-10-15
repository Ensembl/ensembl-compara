package Bio::EnsEMBL::Compara::RunnableDB::Families::ParseMCLintoFamilies;

# RunnableDB to parse the MCL output and load the families

use strict;
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

    my $mcl_name        = $self->param('mcl_name')      || die "'mcl_name' is an obligatory parameter, please set it in the input_id hashref";
    my $family_prefix   = $self->param('family_prefix') || 'ENSF';
    my $family_offset   = $self->param('family_offset') || 0;

    my $compara_dba     = $self->compara_dba();

        # make sure we have the correct $mlss:
    my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method             => Bio::EnsEMBL::Compara::Method->new( -type => 'FAMILY'),
        -species_set_obj    => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => $compara_dba->get_GenomeDBAdaptor->fetch_all ),
    );
    $compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);

    my $fa            = $compara_dba->get_FamilyAdaptor();
    my $ma            = $compara_dba->get_MemberAdaptor();
    my $cluster_index = 1;

    open (MCL, $mcl_name) || die "could not open '$mcl_name' for reading: $!";
    while (my $line = <MCL>) {
        chomp $line;

        my @cluster_members = split(/\s+/, $line);

        if( (scalar(@cluster_members) == 0)
        or ((scalar(@cluster_members) == 1) and ($cluster_members[0] eq '0'))) {
            print STDERR "Skipping an empty cluster $cluster_index\n" if($self->debug);
            next;
        }

        print STDERR "Loading cluster $cluster_index..." if($self->debug);

        my $family_stable_id = sprintf ("$family_prefix%011.0d",$cluster_index + $family_offset);
        my $family = Bio::EnsEMBL::Compara::Family->new_fast({
            '_stable_id'                    => $family_stable_id,
            '_version'                      => 1,
            '_method_link_species_set'      => $mlss,
            '_method_link_species_set_id'   => $mlss->dbID,
            '_description_score'            => 0,
        });

        foreach my $tab_idx (@cluster_members) {

            if( my $member = $ma->fetch_all_by_sequence_id($tab_idx)->[0] ) {
                # A funny way to add members to a family.
                # You cannot do it without introducing a fake AlignedMember, it seems?
                #
                bless $member, 'Bio::EnsEMBL::Compara::AlignedMember';
                $family->add_Member($member);
            } else {
                warn "Could not fetch member by sequence_id=$tab_idx";
            }
        }

        my $family_dbID = $fa->store($family);

        $cluster_index++;

        print STDERR "Done\n" if($self->debug);
    }
    close MCL;
}

1;
