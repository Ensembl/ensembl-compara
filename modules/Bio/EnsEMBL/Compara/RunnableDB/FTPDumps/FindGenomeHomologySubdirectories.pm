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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FindGenomeHomologySubdirectories

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::FindGenomeHomologySubdirectories;

use strict;
use warnings;

use File::Find;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
    my $self = shift;

    my $search_path = $self->param_required('search_path');
    $search_path =~ s|/+$||;

    my %sub_dir_set;
    {
        local $File::Find::dont_use_nlink = 1;

        find(sub {
            my $dir_path = $File::Find::dir;
            $dir_path =~ s|/+$||;
            if (/\.gz$/ && $dir_path ne $search_path) {
                $sub_dir_set{$dir_path} = 1;
            }
        }, $search_path);
    }

    my @directories = sort keys %sub_dir_set;
    $self->param('directories', \@directories);
}


sub write_output {
    my $self = shift;

    my $directories = $self->param('directories');

    foreach my $directory (@{$directories}) {
        $self->dataflow_output_id( { directory => $directory }, 2 );
    }
}


1;
