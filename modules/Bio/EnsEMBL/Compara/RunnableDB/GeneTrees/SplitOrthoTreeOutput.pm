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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SplitOrthoTreeOutput

=head1 DESCRIPTION

Filter the matching mlss lines from all files under the orthotree_dir
and write them to mlss-specific files

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::SplitOrthoTreeOutput;

use warnings;
use strict;

use File::Find;
use IO::File;

use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);
use Bio::EnsEMBL::Hive::Utils ('dir_revhash');

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    # create hash of file handles and print file headers
    my %mlss_fhs;
    my %mlss_filenames;
    foreach my $mlss_id ( @{ $self->param_required('mlss_ids') } ) {
        $self->_get_mlss_filehandle($mlss_id, \%mlss_filenames, \%mlss_fhs);
    }

    my $orthotree_files = $self->orthotree_files;
    foreach my $file ( @$orthotree_files ) {
        print "checking $file...\n";
        open( my $ofh, '<', $file );
        my $header_line = <$ofh>;
        my @header_cols = split( /\s+/, $header_line );
        while ( my $line = <$ofh> ) {
            chomp $line;
            my $row = map_row_to_header($line, \@header_cols);
            my $mlss_id = $row->{'mlss_id'};
            if (defined $mlss_fhs{$mlss_id}) {
                $mlss_fhs{$mlss_id}->print("$line\n");
            }
        }
    }

    foreach my $fh ( values %mlss_fhs ) {
        $fh->close;
    }

    print "wrote to :\n\t- " . join(
        "\n\t- ", 
        values %mlss_filenames
    ) . "\n\n";
}

sub _get_mlss_filehandle {
    my ( $self, $mlss_id, $mlss_filenames, $mlss_fhs ) = @_;

    # set up directory
    my $homology_dumps_dir = $self->param_required('homology_dumps_dir');
    my $member_type        = $self->param_required('member_type');
    my $mlss_id_rev_hash = dir_revhash($mlss_id);
    my $mlss_dir = join('/', ( $homology_dumps_dir, $mlss_id_rev_hash ));
    $self->run_command("mkdir -p $mlss_dir");

    # native file handles kept going out of scope and
    # being closed - use IO::File handles instead
    my $mlss_file = "$mlss_dir/$mlss_id.$member_type.homologies.tsv";
    if (-e $mlss_file) {
        if ( $self->param('overwrite') ) {
            unlink $mlss_file;
        } else {
            die "$mlss_file already exists. Pass the 'overwrite' param to allow overwriting";
        }
    }
    my $mlss_fh = IO::File->new();
    $mlss_fh->open($mlss_file, '>') or die "Cannot open $mlss_file for writing";

    # write header line
    $mlss_fh->print(join("\t", @{ $Bio::EnsEMBL::Compara::Homology::object_summary_headers }) . "\n");

    $mlss_filenames->{$mlss_id} = $mlss_file;
    $mlss_fhs->{$mlss_id}       = $mlss_fh;
}

sub orthotree_files {
    my $self = shift;

    local $File::Find::dont_use_nlink = 1;

    my @files;
    my $orthotree_dir = $self->param_required('orthotree_dir');
    find(sub {
        push @files, $File::Find::name if /\.orthotree.tsv$/;
    }, $orthotree_dir);

    $self->param('orthotree_files', \@files);
    return \@files;
}

1;
