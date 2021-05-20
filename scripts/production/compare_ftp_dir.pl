#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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


use strict;
use warnings;

=head1 NAME

compare_ftp_dir.pl

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script will assess whether a directory contains the correct data for
the FTP, taking another directory as reference.

There are options to compare against the previous release (the new
directory should be bigger) and the staging area (the content should be the
same).

=head1 SYNOPSIS

 perl compare_ftp_dir.pl
    --curr_dir path/to/current/ftp/dir
    --prev_dir path/to/previous/ftp/dir
    --division <division>
    --bigger | --equal
    [--help]

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 PATHS

=over

=item B<--curr_dir path/to/current/ftp/dir>

The path to the current (new) FTP structure that is being assessed.

=item B<--prev_dir path/to/previous/ftp/dir>

The path to a reference (e.g. the previous) FTP structure to compare against.

=back

=head2 OPTIONS

=over

=item B<--division>

Mandatory. The division you're working on.

=item B<--bigger | --equal>

One these two options must be provided. The script will then check
that the new FTP is either bigger or the same as the reference one.

=back

=head1 EXAMPLES

 # In e96, to check that the rsync is complete
 $ perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/compare_ftp_dir.pl -curr_dir /nfs/production/panda/ensembl/production/ensemblftp/release-96/ -prev_dir /hps/nobackup2/production/ensembl/mateus/release_dumps_ensembl_96/release-96 -division vertebrates -equal
 # In e96, to compare against e95
 $ perl $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/compare_ftp_dir.pl -curr_dir /nfs/production/panda/ensembl/production/ensemblftp/release-96/ -prev_dir /nfs/production/panda/ensembl/production/ensemblftp/release-95/ -division vertebrates -bigger

=cut

use File::Basename;
use File::Spec;
use Getopt::Long;
use Pod::Usage;
use Test::Deep;
use Test::More;


my $help;
my $curr_base_path;
my $prev_base_path;
my $equal;
my $bigger;
my $division;

GetOptions(
    'help'          => \$help,
    'curr_dir=s'    => \$curr_base_path,
    'prev_dir=s'    => \$prev_base_path,
    'bigger'        => \$bigger,
    'equal'         => \$equal,
    'division=s'    => \$division,
);

# Print Help and exit if help is requested
if ($help or !$curr_base_path or !$prev_base_path or ($equal and $bigger) or (!$equal and !$bigger) or !$division) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

my @compara_dirs;
if ( $division eq 'vertebrates' ) {
    @compara_dirs = (
        'bed/ensembl-compara',
        'compara/conservation_scores',
        'compara/species_trees',
        'emf/ensembl-compara/homologies',
        'emf/ensembl-compara/multiple_alignments',
        'fasta/ancestral_alleles',
        'maf/ensembl-compara/multiple_alignments',
        'maf/ensembl-compara/pairwise_alignments',
        'tsv/ensembl-compara/homologies',
        'xml/ensembl-compara/homologies',
    );
} elsif ( $division =~ /^pan($|[^a-z])/ ) {
    @compara_dirs = (
        'compara/species_trees',
        'emf/ensembl-compara/homologies',
        'tsv/ensembl-compara/homologies',
        'xml/ensembl-compara/homologies',
    );
} else {
    @compara_dirs = (
        'compara/species_trees',
        'emf/ensembl-compara/homologies',
        'maf/ensembl-compara/pairwise_alignments',
        'tsv/ensembl-compara/homologies',
        'xml/ensembl-compara/homologies',
    );
}

my %can_subdirs_be_smaller = map {$_ => 1} (
    'bed/ensembl-compara',
    'compara/conservation_scores',
    'tsv/ensembl-compara/homologies',
);
my @compara_files= (
    'compara/multi_division_hmm_lib.tar.gz',
);
my %can_file_be_smaller = map {$_ => 1} (
    'compara/multi_division_hmm_lib.tar.gz',
);

sub extract_stats {
    my $dirname = shift;

    # Hash structure will file information about this directory
    my %stats = (
        name            => basename($dirname),
        path            => $dirname,
        file_count      => 0,
        total_file_size => 0,
        file_count_rec  => 0,
        total_size_rec  => 0,
        dir_count       => 0,
        dir_stats       => {},
    );

    # 88_mammals.gerp_constrained_element -> mammals.gerp_constrained_element
    my $nickname = $stats{name};
    $nickname =~ s/^[0-9]*_// if $nickname =~ /^[0-9]+_\w+\.\w+$/;
    $stats{nickname} = $nickname;

    opendir(my $dirh, $dirname) || die "Error opening '$dirname': $!";
    while (my $filename = readdir($dirh)) {
        next if $filename eq '.';
        next if $filename eq '..';
        if (-l $filename) {
            $filename = readlink $filename;
        }
        my $filepath = File::Spec->catfile($dirname, $filename);
        if (-f $filepath) {
            $stats{file_count} ++;
            $stats{file_count_rec} ++;
            $stats{total_file_size} += -s $filepath;
            $stats{total_size_rec} += -s $filepath;
        } elsif (-d $filepath) {
            $stats{dir_count} ++;
            my $subdir_stats = extract_stats($filepath);
            $stats{dir_stats}->{$filename} = $subdir_stats;
            $stats{total_size_rec} += $subdir_stats->{total_size_rec};
            $stats{file_count_rec} += $subdir_stats->{file_count_rec};
        } else {
            die "Unknown entry type: $filename in $dirname";
        }
    }
    closedir($dirh);
    return \%stats;
}


sub _hide_path {
    my $x = shift;
    if (ref($x) eq 'HASH') {
        delete $x->{path};
        _hide_path($_) for values %{$x->{dir_stats}};
    }
}

sub _assert_bigger {
    my ($h1, $h2, $check_size_here, $chec_size_rec) = @_;
    subtest "More data in ".$h1->{name}, sub {
        my @keys = qw(file_count file_count_rec dir_count);
        push @keys, qw(total_file_size total_size_rec) if $check_size_here;
        foreach my $key (@keys) {
            cmp_ok($h1->{$key}, '>=', $h2->{$key}, $key);
        }
        # Compare by nickname
        my %nick1 = map {$_->{nickname} => $_} values %{$h1->{dir_stats}};
        my %nick2 = map {$_->{nickname} => $_} values %{$h2->{dir_stats}};
        foreach my $subdir (keys %nick1) {
            if (exists $nick2{$subdir}) {
                _assert_bigger($nick1{$subdir}, $nick2{$subdir}, $check_size_here && $chec_size_rec, $chec_size_rec);
            }
        }
    };
}

sub _assert_gerp_dir {
    my ($stats) = @_;
    $stats->{name} =~ m/^([0-9-]+)_/;
    my $n_species = $1;
    subtest $stats->{name}, sub {
        is($stats->{file_count}, $n_species+2, '1 file per species + MD5SUM + README');
        is($stats->{dir_count}, 0, 'No subdirectories');
    };
}

foreach my $d (@compara_dirs) {
    my $curr_dir = File::Spec->catfile($curr_base_path, $d);
    my $prev_dir = File::Spec->catfile($prev_base_path, $d);
    subtest $d, sub {
        # A) Check completeness
        ok(-d $curr_dir, "Directory exists");
        return unless -d $curr_dir;
        my $stats_curr = extract_stats($curr_dir);
        my $stats_prev = extract_stats($prev_dir);
        if (($d eq 'bed/ensembl-compara') or ($d eq 'compara/conservation_scores')) {
            subtest 'Correct content', sub {
                _assert_gerp_dir($_) for values %{$stats_curr->{dir_stats}};
            };
        }
        # B) Compare against another directory
        if ($equal) {
            _hide_path($stats_curr);
            _hide_path($stats_prev);
            is_deeply($stats_curr, $stats_prev, 'Same content');
        } else {
            _assert_bigger($stats_curr, $stats_prev, 1, $can_subdirs_be_smaller{$d} ? 0 : 1);
        }
    };
}

foreach my $f (@compara_files) {
    my $curr_file = File::Spec->catfile($curr_base_path, $f);
    my $prev_file = File::Spec->catfile($prev_base_path, $f);
    subtest $f, sub {
        # A) Check completeness
        ok(-f $curr_file, 'File exists');
        # B) Compare against another directory
        if ($equal) {
            is(-s $curr_file, -s $prev_file, 'Same size');
        } elsif (!$can_file_be_smaller{$f}) {
            cmp_ok(-s $curr_file, '>=', -s $prev_file, 'Bigger size');
        }
    };
}

done_testing();
