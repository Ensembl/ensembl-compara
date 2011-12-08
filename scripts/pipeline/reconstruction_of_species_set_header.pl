#!/usr/bin/env perl

# This is a script to aid the transition from "headerless" species_set schema
# to the schema where species_set_header table generates and maintains unique species_set_ids

use strict;
use warnings;
use Data::Dumper;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $starting_from_rel = 49;     # 49 is the earliest
my $current_rel       = 62;     # 62 is the current
my $header_table_name = 'species_set_header';

sub get_compara_url {
    my $rel = shift @_;

    if($rel eq 'master') {
        return "mysql://ensro\@compara1/sf5_ensembl_compara_master";
#    } elsif($rel == 61) {
#        return "mysql://ensro\@compara1/sf5_ensembl_compara_61";
    } elsif((48<=$rel) and ($rel<=$current_rel)) {
        return "mysql://ensro\@ensdb-archive:5304/ensembl_compara_$rel";
    } elsif((29<=$rel) and ($rel<=47)) {
        return "mysql://ensro\@ensdb-archive:3304/ensembl_compara_$rel";
    }

    return 'mysql://ensro@compara1/sf5_ensembl_compara_master';
}


sub get_contents {
    my $rel = shift @_;

    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url($rel) )->dbc();

    my %id_to_contents = ();
    my $sth = $dbc->prepare(q{
        SELECT ss.species_set_id,
            GROUP_CONCAT(distinct ss.genome_db_id) x,
    }.(($rel eq 'master' or $rel>=57)
        ? q{ IFNULL(GROUP_CONCAT(distinct mlss.name),CONCAT('COLOURED:',sst.value)) y }
        : ' GROUP_CONCAT(distinct mlss.name) y '
    ).q{
        FROM species_set ss
        LEFT JOIN method_link_species_set mlss ON ss.species_set_id=mlss.species_set_id
    }.(($rel eq 'master' or $rel>=57)
        ? q{ LEFT JOIN species_set_tag sst ON ss.species_set_id=sst.species_set_id AND sst.tag='name' }
        : ''
    ).q{
        GROUP BY species_set_id
    });
    $sth->execute();
    while(my ($set_id, $contents, $names) = $sth->fetchrow_array()) {
        $id_to_contents{$set_id} = { 'contents' => [split (/,/, $contents) ], 'names' => $names };
    }
    $sth->finish();

    return \%id_to_contents;
}


sub get_name_mapping {
    my $rel = shift @_;

    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url($rel) )->dbc();

    my %id_2_name = ();
    my $sth = $dbc->prepare(' SELECT genome_db_id, name FROM genome_db ');
    $sth->execute();
    while(my ($genome_db_id, $name) = $sth->fetchrow_array()) {
        $id_2_name{$genome_db_id} = $name;
    }
    $sth->finish();

    return \%id_2_name;
}


sub find_ss {
    foreach my $rel ($starting_from_rel..$current_rel) {
        my $rel_contents = get_contents($rel);

        foreach my $set_id (@_) {

            if($rel_contents->{$set_id}) {
                print "$set_id found in rel $rel\n";
            }
        }
    }
}


sub main {

    my $master_contents = get_contents('master');
    my $master_name = get_name_mapping('master');

    my %present_in_rel = ();

    foreach my $rel ($starting_from_rel..$current_rel) {
        my $rel_contents = get_contents($rel);

        foreach my $set_id (keys %$master_contents) {

            if($rel_contents->{$set_id}) {
                push @{$present_in_rel{$set_id}}, $rel;
            }
        }
    }
    print "CREATE TABLE IF NOT EXISTS $header_table_name (species_set_id INT NOT NULL AUTO_INCREMENT, name VARCHAR(255), set_size INT, first_release INT, last_release INT, PRIMARY KEY (species_set_id), KEY (name) );\n\n";

    foreach my $set_id (sort {$a <=> $b} keys %present_in_rel) {
        my @genome_dbs        = @{$master_contents->{ $set_id }{'contents'}};
        my $set_size          = scalar(@genome_dbs);
        my @releases_present  = @{$present_in_rel{$set_id}};
        my $first_rel_present = $releases_present[0];
        my $last_rel_present  = $releases_present[scalar(@releases_present)-1];
        if($last_rel_present == $current_rel) {
            $last_rel_present = 'NULL';
        }

        my $names = $master_contents->{$set_id}{'names'};

        my $ss_name = 'UNKNOWN';
        if($set_size==1 and $names=~/^(\w\.\w\w\w) paralogues$/) {
            $ss_name = $master_name->{$genome_dbs[0]};
        } elsif($set_size==2 and $names=~/(\w\.\w\w\w-\w\.\w\w\w) (paralogues|orthologues)/) {
            $ss_name = join('-', sort map { $master_name->{$_} } @genome_dbs);
        } elsif($set_size>2 and $names=~/^${set_size} (\w+(?: \w+)?) (Pecan|EPO)/) {
            $ss_name = $1;
        } elsif($set_size>2 and $names=~/^COLOURED:([\w\-]+)$/) {
            $ss_name = $1;
        } elsif($set_size>2 and $names=~/^(protein trees|families)/) {
            $ss_name = 'all species';
        }
        
        print "REPLACE INTO $header_table_name (species_set_id, name, set_size, first_release, last_release) VALUES ($set_id, '$ss_name', $set_size, $first_rel_present, $last_rel_present);\n";
    }
}

main();

