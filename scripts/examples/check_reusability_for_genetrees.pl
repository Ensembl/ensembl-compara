#!/usr/local/bin/perl -w

# This is an example script that finds which of the core databases living on staging servers
# have the same coding exons as the previous version (so the corresponding members can be reused in GeneTrees pipeline).
#
# This functionality is being reworked into a RunnableDB module, to be used as a part of the pipeline.

use strict;
use Bio::EnsEMBL::Registry;

# my %interesting_species = map { $_ => 1} ('saccharomyces_cerevisiae', 'drosophila_melanogaster', 'mus_musculus', 'homo_sapiens', 'callithrix_jacchus');
my %interesting_species = ();

unless(scalar(@ARGV)==2) {
    die "Correct usage:\n\t$0 <current_on_livemirror> <current_release>\n";
}

my ($curr_on_livemirror, $curr_release) = @ARGV;
my $prev_release = $curr_release-1;

my @sources_of_previous_release = (
    {   '-host'         => 'ens-livemirror.internal.sanger.ac.uk',
        '-port'         => 3306,
        '-user'         => 'ensro',
        '-pass'         => '',
    },
);

my @sources_of_current_release = (
    $curr_on_livemirror ? (
        {   '-host'         => 'ens-livemirror.internal.sanger.ac.uk',
            '-port'         => 3306,
            '-user'         => 'ensro',
            '-pass'         => '',
        },
    ) : (
        {   '-host'         => 'ens-staging.internal.sanger.ac.uk',
            '-port'         => 3306,
            '-user'         => 'ensro',
            '-pass'         => '',
        },
        {   '-host'         => 'ens-staging2.internal.sanger.ac.uk',
            '-port'         => 3306,
            '-user'         => 'ensro',
            '-pass'         => '',
        },
    )
);

my $suffix_separator = '__cut_here__';

sub Bio::EnsEMBL::DBSQL::DBAdaptor::extract_assembly_name {
    my $self = shift @_;

    my ($cs) = @{$self->get_CoordSystemAdaptor->fetch_all()};
    my $assembly_name = $cs->version;

    return $assembly_name;
}

sub hash_all_exons_from_dbc {
    my $dbc = shift @_;

    my $sql = qq{
        SELECT CONCAT(tsi.stable_id, ':', e.seq_region_start, ':', e.seq_region_end)
          FROM transcript_stable_id tsi, transcript t, exon_transcript et, exon e
         WHERE tsi.transcript_id=t.transcript_id
           AND t.transcript_id=et.transcript_id
           AND et.exon_id=e.exon_id
           AND t.biotype='protein_coding'
    };

    my %exon_set = ();

    my $sth = $dbc->prepare($sql);
    $sth->execute();

    while(my ($key) = $sth->fetchrow()) {
        $exon_set{$key} = 1;
    }

    return \%exon_set;
}

sub check_presence {
    my ($from_exons, $to_exons) = @_;

    my @presence = (0, 0);

    foreach my $from_exon (keys %$from_exons) {
        $presence[ exists($to_exons->{$from_exon}) ? 1 : 0 ]++;
    }
    return @presence;
}

sub main () {


        # load the prev.release registry:
    foreach my $src_conn (@sources_of_previous_release) {
        Bio::EnsEMBL::Registry->load_registry_from_db( %{ $src_conn }, -db_version => $prev_release, -species_suffix => $suffix_separator.$prev_release );
    }

        # load the curr.release registry:
    foreach my $src_conn (@sources_of_current_release) {
        Bio::EnsEMBL::Registry->load_registry_from_db( %{ $src_conn }, -db_version => $curr_release, -species_suffix => $suffix_separator.$curr_release );
    }

    Bio::EnsEMBL::Registry->no_version_check(1);

    my (@reuse_names, @fresh_names);

    foreach my $core_dba ( @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors( -group => 'core') } ) {
        my $full_species_name = $core_dba->species;
        my ($species_name, $rel) = split(/$suffix_separator/, $full_species_name);
        next if( $rel!=$curr_release or $species_name=~/ancestral/i );

        next if(scalar(keys %interesting_species) and !$interesting_species{$species_name});

        warn "\n$species_name:\n";
        my $curr_core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species_name.$suffix_separator.$curr_release, 'core') or die "Could not load rel.$curr_release '$species_name' database";

        if(my $prev_core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species_name.$suffix_separator.$prev_release, 'core')) {

            my $curr_assembly = $curr_core_dba->extract_assembly_name;
            my $prev_assembly = $prev_core_dba->extract_assembly_name;

            if($curr_assembly ne $prev_assembly) {

                warn "Assemblies do not match ($prev_assembly -> $curr_assembly), so cannot reuse\n";
                push @fresh_names, $species_name;

            } else {

                warn "Comparing rel.$prev_release to rel.$curr_release '$species_name' coding exons...\n";

                my $prev_exons = hash_all_exons_from_dbc( $prev_core_dba->dbc() );
                my $curr_exons = hash_all_exons_from_dbc( $curr_core_dba->dbc() );
                my ($removed, $remained1) = check_presence($prev_exons, $curr_exons);
                my ($added, $remained2) = check_presence($curr_exons, $prev_exons);

                my $coding_exons_differ = $added || $removed;
                warn "There was ".($coding_exons_differ ? 'A' : 'NO')." change in coding exons.\n";

                if($coding_exons_differ) {
                    push @fresh_names, $species_name;
                } else {
                    push @reuse_names, $species_name;
                }
            }

        } else {

            warn "There was no '$species_name' in rel.$prev_release\n";
            push @fresh_names, $species_name;

        }
    }

    warn "\n\n\nComparison completed.\n";
    warn ''.scalar(@reuse_names).' core databases can be reused : '.join(', ', @reuse_names)."\n\n";
    warn ''.scalar(@fresh_names).' core databases will have to be blasted afresh: '.join(', ', @fresh_names)."\n\n";
}

main();

