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

Bio::EnsEMBL::Compara::RunnableDB::Families::DownloadAndChunkUniProtFile

=head1 DESCRIPTION

This module downloads a data file from the UniProt FTP site and splits it
in smaller files that can be read by the next analysis

=cut

package Bio::EnsEMBL::Compara::RunnableDB::Families::DownloadAndChunkUniProtFile;

use strict;
use warnings;

use File::Path;

use Bio::EnsEMBL::Hive::Utils ('dir_revhash');

use base ('Bio::EnsEMBL::Hive::Process');

sub param_defaults {
    return {
        'uniprot_input_cmd' => 'wget -q -O - #uniprot_ftp_url# | gunzip',   # how to get the Uniprot file
        'buffer_size'       => 1600,          # how many uniprot_ids are fetched per one execution of mfetch
    };
}

sub fetch_input {
    my $self = shift @_;

    my $uniprot_dir = $self->param_required('uniprot_dir');
    my $uniprot_source = $self->param_required('uniprot_source');
    my $uniprot_tax_div = $self->param_required('tax_div');

    my $curr_size = 0;
    my $curr_out_fh = undef;
    my $curr_file_name = undef;
    my $chunk_id = 0;

    warn "My source is '".$self->param_required('uniprot_input_cmd')."'\n" if $self->debug;
    open(my $in_fh, '-|', $self->param_required('uniprot_input_cmd'));
    while(<$in_fh>) {
        if (/^ID/) {
            if ($curr_size == $self->param('buffer_size')) {
                #warn "close and dataflow chunk $chunk_id $curr_file_name\n";
                close($curr_out_fh);
                $self->dataflow_output_id( {'uniprot_file' => $curr_file_name, 'file_size' => $curr_size}, 2);
                $curr_size = 0;
            }
            unless ($curr_size) {
                $chunk_id++;
                my $curr_file_dir = $uniprot_dir . '/' . dir_revhash($chunk_id);
                mkpath($curr_file_dir);
                $curr_file_name = $curr_file_dir . sprintf('/chunk.%d.%s.%s.dat', $chunk_id, $uniprot_source, $uniprot_tax_div);
                open($curr_out_fh, '>', $curr_file_name) or die "Could not open '$curr_file_name' for writing: $!\n";
                #warn "created new chunk $chunk_id $curr_file_name\n";
            }
            $curr_size++;
            #warn "record ${curr_size} in chunk $chunk_id $curr_file_name\n";
        }
        print $curr_out_fh $_;
    }
    close($in_fh);
    close($curr_out_fh);
    $self->dataflow_output_id( {'uniprot_file' => $curr_file_name, 'file_size' => $curr_size}, 2);
}

1;

