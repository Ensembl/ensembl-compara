=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CheckNotEmpty

=head1 DESCRIPTION

This Runnable checks that the given file has the required minimum number of lines.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CheckNotEmpty;

use strict;
use warnings;

use Capture::Tiny qw(tee);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'min_number_of_lines'   => 1,   # By default we check for "pure" non-emptyness
    }
}


sub fetch_input {
    my $self = shift @_;

    foreach my $file (glob($self->param_required('filename'))) {
        my $size = tee { system('wc', '-l', $file) };
        $size =~ /^(\d+)\s/;
        if ($1 < $self->param_required('min_number_of_lines')) {
            die "$file only has $1 lines\n";
        }
    }
}


1;
