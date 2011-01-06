package Bio::EnsEMBL::Compara::RunnableDB::Families::ParseMCLintoFamilies;

# RunnableDB to parse the MCL output and load the families

use strict;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Attribute;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {   # nothing to fetch here, just write_output()
}

sub run {   # nothing to run, just write_output()
}

sub write_output {
    my $self = shift @_;

    my $mcl_name        = $self->param('mcl_name')      || die "'mcl_name' is an obligatory parameter, please set it in the input_id hashref";
    my $family_prefix   = $self->param('family_prefix') || 'ENSF';
    my $family_offset   = $self->param('family_offset') || 1;

    my $compara_dba     = $self->compara_dba();

        # make sure we have the correct $mlss:
    my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
    $mlss->species_set(\@{$compara_dba->get_GenomeDBAdaptor->fetch_all});
    $mlss->method_link_type('FAMILY');
    $compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);


    my $fa            = $compara_dba->get_FamilyAdaptor();
    my $ma            = $compara_dba->get_MemberAdaptor();
    my $cluster_index = 0;

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
            '_stable_id'               => $family_stable_id,
            '_version'                 => 1,
            '_method_link_species_set' => $mlss,
            '_description_score'       => 0,
        });

        foreach my $tab_idx (@cluster_members) {

            my ($member) = @{ $ma->fetch_all_by_sequence_id($tab_idx) };
            unless($member) {
                warn "Could not fetch member by sequence_id=$tab_idx";
            }

            if($member) {
                # A funny way to add members to a family.
                # You cannot do it without introducing an empty attribute, it seems?
                #
                my $attribute = new Bio::EnsEMBL::Compara::Attribute;
                $family->add_Member_Attribute([$member, $attribute]);
            }
        }

        my $family_dbID = $fa->store($family);

        $cluster_index++;

        print STDERR "Done\n" if($self->debug);
    }
    close MCL;
}

1;
