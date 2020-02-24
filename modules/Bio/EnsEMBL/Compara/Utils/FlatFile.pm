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

=head1 NAME

Bio::EnsEMBL::Compara::Utils::FlatFile

=head1 DESCRIPTION

Utility methods for handling flatfiles

=cut

package Bio::EnsEMBL::Compara::Utils::FlatFile;

use strict;
use warnings;
use base qw(Exporter);

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    map_row_to_header
    parse_flatfile_into_hash
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);

=head2 map_row_to_header

    To avoid hard-coding array indexes, map the values in each row based on the
    header line. This way, it doesn't matter if we add extra fields to the input
    file

=cut

sub map_row_to_header {
    my ($line, $header) = @_;
    
    chomp $line;
    chomp $header;
    my @cols      = split(/\s+/, $line);
    my @head_cols;
    if ( ref $header eq 'ARRAY' ) {
        @head_cols = @$header;
    } else {
        @head_cols = split(/\s+/, $header);
    }
    
    die "Number of columns in header do not match row" unless scalar @cols == scalar @head_cols;
    
    my $row;
    for ( my $i = 0; $i < scalar @cols; $i++ ) {
        $row->{$head_cols[$i]} = $cols[$i];
    }
    return $row;
}

=head2 parse_flatfile_into_hash

    A two column file is parsed into $column_1->$column_2

=cut

sub parse_flatfile_into_hash {
    my ($self, $filename, $filter) = @_;

    my %flatfile_hash;
    open(my $fh, '<', $filename) or die "Cannot open $filename for reading";
    my $header = <$fh>;
    while ( my $line = <$fh> ) {
        chomp $line;
        my ( $id, $val ) = split(/\s+/, $line);
        next if $val eq '';
        next if $filter && ! $self->match_range_filter($id, $filter);
        $flatfile_hash{$id} = $val;
    }
    close $fh;

    return \%flatfile_hash;
}

1;
