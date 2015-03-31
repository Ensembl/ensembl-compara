#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


# This is a script to aid the transition to "first_release" /
# "last_release" in the genome_db table from only "assembly_default"

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $starting_from_rel = 24;     # 49 is the earliest
my $current_rel       = 79;     # 79 is the current

$| = 1;

sub get_compara_url {
    my $rel = shift @_;

    if($rel eq 'master') {
        #return "mysql://ensro\@compara1/sf5_ensembl_compara_master";
        return "mysql://ensadmin:$ENV{ENSADMIN_PSW}\@compara1/mm14_test_master";
    } elsif((48<=$rel) and ($rel<=$current_rel)) {
        return "mysql://anonymous\@ensembldb.ensembl.org:5306/ensembl_compara_$rel";
    } elsif((29<=$rel) and ($rel<=47)) {
        return "mysql://anonymous\@ensembldb.ensembl.org:4306/ensembl_compara_$rel";
    } elsif((24<=$rel) and ($rel<=28)) {
        return "mysql://anonymous\@ensembldb.ensembl.org:4306/ensembl_compara_${rel}_1";
    } else {
        die "Release $rel cannot be reached\n";
    }
}


sub get_contents {
    my $rel = shift @_;

    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url($rel) )->dbc();

    my %id_to_contents = ();
    my $sth = $dbc->prepare(q{SELECT genome_db_id, name, assembly, genebuild FROM genome_db});
    $sth->execute();
    while(my $h = $sth->fetchrow_hashref()) {
        my $set_id = $h->{genome_db_id};
        delete $h->{genome_db_id};
        $id_to_contents{$set_id} = $h;

        # Names used to be like "Homo sapiens" but now are like "homo_sapiens"
        my $name = $h->{name};
        $name =~ s/ /_/g;
        $h->{name} = lc $name;
    }
    $sth->finish();

    return \%id_to_contents;
}


sub sprintf_gdb {
    my $self = shift;
    return join('/', $self->{name}, $self->{assembly}, $self->{genebuild});
}


sub main {

    my $master_contents = get_contents('master');

    my %first_rel = ();
    my %last_rel = ();

    my $last = undef;

    foreach my $rel ($starting_from_rel..$current_rel) {
        my $rel_contents = get_contents($rel);
        print "\n**** This is release $rel ****\n";
        #print Dumper($rel_contents);

        if ($last) {
            foreach my $dbID (keys %$last) {
                next unless $master_contents->{$dbID};
                if ($rel_contents->{$dbID}) {
                    if (($last->{$dbID}->{name} ne $rel_contents->{$dbID}->{name}) or ($last->{$dbID}->{assembly} ne $rel_contents->{$dbID}->{assembly})) {
                        warn "Same genome_db_id ($dbID) but different contents !\n\twas ".sprintf_gdb($last->{$dbID})."\n\tis ".sprintf_gdb($rel_contents->{$dbID})."\n";
                    } else {
                        #print "$dbID still there and identical\n";
                    }
                } else {
                    if ($last_rel{$dbID}) {
                        warn "$dbID: ".sprintf_gdb($last->{$dbID})." has been removed AGAIN in e$rel\n";
                    } else {
                        print "$dbID: ".sprintf_gdb($last->{$dbID})." has been removed in e$rel\n";
                        $last_rel{$dbID} = $rel-1;
                    }
                }
            }
            foreach my $dbID (keys %$rel_contents) {
                next unless $master_contents->{$dbID};
                next if $last->{$dbID};

                if ($first_rel{$dbID}) {
                    warn "$dbID: ".sprintf_gdb($rel_contents->{$dbID})." has REAPPEARED in e$rel\n"
                } else {
                    $first_rel{$dbID} = $rel;
                    print "$dbID: ".sprintf_gdb($rel_contents->{$dbID})." has appeared in e$rel\n"
                }
            }
        } else {
            foreach my $dbID (keys %$rel_contents) {
                next unless $master_contents->{$dbID};

                $first_rel{$dbID} = $rel;
                print "$dbID: ".sprintf_gdb($rel_contents->{$dbID})." has appeared in e$rel (or before)\n"
            }
        }

        $last = $rel_contents;

    }

    print "\n*** FINAL ***\n";

    my $dbc = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new( -url=> get_compara_url('master') )->dbc();
    my $sql = 'UPDATE genome_db SET first_release = ?, last_release = ? WHERE genome_db_id = ?';
    my $sth = $dbc->prepare($sql);
    foreach my $dbID (sort {$a <=> $b} keys %$master_contents) {
        print $first_rel{$dbID} || 'NEVER', ' -> ', $last_rel{$dbID} || ($first_rel{$dbID} ? 'CUR' : 'NEVER'), ' ', sprintf_gdb($master_contents->{$dbID}), "\n";
        #$sth->execute($first_rel{$dbID}, $last_rel{$dbID}, $dbID);
    }
    $sth->finish();
}

main();

