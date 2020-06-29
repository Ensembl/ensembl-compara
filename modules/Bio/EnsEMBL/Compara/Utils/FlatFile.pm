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

use File::Find;

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    map_row_to_header
    parse_flatfile_into_hash
    match_range_filter
    query_file_tree
    group_hash_by
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

=head2 match_range_filter

    Range filter to collect appropriate ncrna or protein ids

=cut

sub match_range_filter {
    my ($self, $id, $filter) = @_;

    my $match = 0;
    foreach my $range ( @$filter ) {
        die "Bad range declaration: at least one value expected, 0 found." unless defined $range->[0];
        if ( defined $range->[1] ) {
            $match = 1 if $id >= $range->[0] && $id <= $range->[1];
        } else {
            $match = 1 if $id >= $range->[0];
        }
    }

    return $match;
}

=head2 query_file_tree

  Arg [1]     : String $directory
  Arg [2]     : (optional) String $file_extension
  Arg [3]     : (optional) String or arrayref $selected_fields
  Arg [4]     : (optional) String or arrayref $group_by
  Description : Fetch data from data files under $directory. By default,
                it will fetch all data from all files and return an arrayref
                of hashrefs, with column names as keys.
                If $file_extension is provided, only files matching this
                extension will be queried.
                If $selected_fields is provided, only the given fields will
                be returned.
                If $group_by is provided, the method will return a hashref
                (nested if more than one group_by term is given), which points
                to an arrayref of hashes.
  Returntype  : arrayref or hashref (if $group_by is given)

=cut

sub query_file_tree {
    my ( $dir, $ext, $select, $group_by ) = @_;

    $select   = [$select]   if defined $select   && ref $select   ne 'ARRAY';
    $group_by = [$group_by] if defined $group_by && ref $group_by ne 'ARRAY';

    # grab the list of files in the $dir
    my $filelist = [];
    my $wanted = sub { _wanted($filelist, ($ext || '.+')) };
    find($wanted, $dir);

    # sort files - important for unit testing (esp travis-ci)
    # as different versions of File::Find traverse in different order
    my @filelist = sort @$filelist;

    # loop through the files and group the data
    my @data;
    foreach my $file ( @filelist ) {
        open( my $fh, '<', $file ) or die "Cannot open $file for reading";
        my $header_line = <$fh>;
        my @header_cols = split(/\s+/, $header_line);
        while ( my $line = <$fh> ) {
            chomp $line;
            my $row = map_row_to_header($line, \@header_cols);
            my $selected_data;
            if ( defined $select ) {
                # extract data from each row, where requested
                # also include fields required for future groupings
                foreach my $selected_field ( @$select, @$group_by ) {
                    $selected_data->{$selected_field} = $row->{$selected_field};
                }
            } else {
                $selected_data = \%$row;
            }
            push( @data, $selected_data );
        }
    }

    # recursively group data if multiple group_by fields exist
    if ( defined $group_by && @$group_by ) {
        my $hashed_data = group_hash_by(\@data, $group_by, $select);
        return $hashed_data;
    } else {
        return \@data;
    }
}

# part of File::Find - define which files to select
sub _wanted {
   return if ! -e;
   my ($files, $ext) = @_;
   push( @$files, $File::Find::name ) if $File::Find::name =~ /\.$ext$/;
}

=head2 group_hash_by

  Arg [1]     : Arrayref $array_of_hashes
  Arg [2]     : Arrayref $group_by
  Arg [3]     : (optional) Arrayref $selected_fields
  Description : Given an array of hashrefs, group the data by the value
                of the fields listed in $group_by and return a hash of
                arrays of hashes. If $selected_fields is provided, prune out
                only these fields.
  Returntype  : hashref

=cut

sub group_hash_by {
    my ( $array_of_hashes, $group_by, $select ) = @_;

    # create copy to correctly handle loops over this recursive method
    my @these_group_by = @$group_by;

    # group by the first given group_by field
    my $this_group_by = shift @these_group_by;
    my %grouped_data;
    foreach my $h ( @$array_of_hashes ) {
        push( @{ $grouped_data{$h->{$this_group_by}} }, $h);
    }

    if ( scalar @these_group_by > 0 ) {
        # recursively create subgroups on subsequent group_bys
        foreach my $k ( keys %grouped_data ) {
            $grouped_data{$k} = group_hash_by( $grouped_data{$k}, \@these_group_by, $select );
        }
    } elsif ( $select ) {
        # no more recursing to do - keep selected keys only
        foreach my $k1 ( keys %grouped_data ) {
            my @selected_data;
            foreach my $h ( @{ $grouped_data{$k1} } ) {
                my %h_select = map { $_ => $h->{$_} } @$select;
                push( @selected_data, \%h_select );
            }
            $grouped_data{$k1} = \@selected_data;
        }
    }

    return \%grouped_data;
}

1;
