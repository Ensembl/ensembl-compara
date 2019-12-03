=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Test

=head1 DESCRIPTION

Utility functions used in test scripts

=cut

package Bio::EnsEMBL::Compara::Utils::Test;

use strict;
use warnings;

use Cwd qw(abs_path);
use File::Spec;
use File::Basename qw/dirname/;

=head2 GLOBAL VARIABLES

=over

=item repository_root

The path to the root of the repository. Kept here so that we don't need
to "compute" it again and again.

=back

=cut

my $repository_root;

=head2 get_repository_root

  Description : Return the path to the root of the repository. Note that
                this is constructed from the path to this module.

=cut

sub get_repository_root {
    return $repository_root if $repository_root;
    my $file_dir = dirname(__FILE__);
    my $original_dir = cwd();
    chdir($file_dir);
    my $cur_dir = cwd();
    chdir($original_dir);
    $repository_root = File::Spec->catdir($cur_dir, File::Spec->updir(), File::Spec->updir(), File::Spec->updir(), File::Spec->updir(), File::Spec->updir());
    return $repository_root;
}

=head2 find_all_files

  Description : Return the list of all the files in the repository.
                Note that the path to the root of the repository
                from this file is hardcoded, as is the list of
                the top-level repository directories.

=cut

sub find_all_files {
    my @queue;
    my @files;

    # First populate the top-level sub-directories
    {
        my $starting_dir = get_repository_root();
        my %subdir_ok = map {$_ => 1} qw(modules scripts sql docs travisci xs);
        opendir(my $dirh, $starting_dir);
        my @dir_content = File::Spec->no_upwards(readdir $dirh);
        foreach my $f (@dir_content) {
            my $af = File::Spec->catfile($starting_dir, $f);
            if ((-d $af) and $subdir_ok{$f}) {
                push @queue, $af;
            }
        }
        closedir $dirh;
    }

    # Recurse into the filesystem
    while ( my $f = shift @queue ) {
        if ( -l $f ) {
        } elsif ( -d $f ) {
            opendir(my $dirh, $f);
            push @queue, map {File::Spec->catfile($f, $_)} File::Spec->no_upwards(readdir $dirh);
            closedir $dirh;
        } else {
            push @files, $f;
        }
    }

    return @files;
}

1;
