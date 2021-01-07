=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::ReuseWGAScore;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::Utils::FlatFile qw(map_row_to_header);
use File::Basename qw/dirname/;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift;

    my $previous_wga_file = $self->param('previous_wga_file');
    my $homology_map_file = $self->param('homology_mapping_flatfile');
    my $output_file       = $self->param('reuse_file');
    $self->run_command( "mkdir -p " . dirname($output_file)) unless -d dirname($output_file);

    # parse homology id map
    open( my $hmfh, '<', $homology_map_file ) or die "Cannot open $homology_map_file for reading";
    my $header = <$hmfh>;
    my @head_cols = split(/\s+/, $header);
    my %homology_id_map;
    while ( my $line = <$hmfh> ) {
        my $row = map_row_to_header( $line, \@head_cols );
        $homology_id_map{$row->{prev_release_homology_id}} = $row->{curr_release_homology_id};
    }
    close $hmfh;

    # loop through previous wga scores and map them to new ids - output to file
    open( my $pwga_fh, '<', $previous_wga_file ) or die "Cannot open $previous_wga_file for reading";
    open( my $out_fh,  '>', $output_file       ) or die "Cannot open $output_file for writing";
    print $out_fh "homology_id\twga_coverage\n";
    my $pwga_header = <$pwga_fh>;
    my @pwga_head_cols = split(/\s+/, $pwga_header);
    while ( my $line = <$pwga_fh> ) {
        my $row = map_row_to_header( $line, \@pwga_head_cols );
        my $curr_hom_id = $homology_id_map{$row->{homology_id}};
        my $wga_score   = $row->{wga_coverage};
        print $out_fh "$curr_hom_id\t$wga_score\n" if $curr_hom_id;
    }
    close $out_fh;
    close $pwga_fh;
}

1;
