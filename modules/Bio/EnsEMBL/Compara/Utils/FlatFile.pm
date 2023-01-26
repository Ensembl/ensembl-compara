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

use Bio::EnsEMBL::Compara::Utils::RunCommand;

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    map_row_to_header
    parse_flatfile_into_hash
    match_range_filter
    query_file_tree
    group_hash_by
    check_column_integrity
    check_for_null_characters
    get_line_count
    check_line_counts
    dump_string_into_file
);
%EXPORT_TAGS = (
  all     => [@EXPORT_OK]
);

=head2 map_row_to_header

    To avoid hard-coding array indexes, map the values in each row based on the
    header line. This way, it doesn't matter if we add extra fields to the input
    file. This subroutine uses `\s+` as default separator between fields. This
    behaviour can be changed using the `delimiter_pattern` parameter. Tab value
    `\t` has been tested

=cut

sub map_row_to_header {
    my ($line, $header, $delimiter_pattern) = @_;
    $delimiter_pattern //= '\s+';
    
    chomp $line;
    chomp $header;
    my @cols      = split(/$delimiter_pattern/, $line, -1);
    my @head_cols;
    if ( ref $header eq 'ARRAY' ) {
        @head_cols = @$header;
    } else {
        @head_cols = split(/$delimiter_pattern/, $header, -1);
    }
    
    die "Number of columns in header (", (scalar @head_cols),") do not match row (", (scalar @cols),")" unless scalar @cols == scalar @head_cols;
    
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

    {
        local $File::Find::dont_use_nlink = 1;
        find($wanted, $dir);
    }

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

=head2 check_column_integrity

    Arg [1]     : $filename
    Arg [2]     : (optional) $delimiter
    Description : Checks that every line of file $filename has an equal number
                  of columns. Splits on whitespace by default, but $delimiter can
                  be defined.
    Returntype  : 1 if file passes check
    Exceptions  : throws if file fails check

=cut

sub check_column_integrity {
    my ($file, $delimiter) = @_;

    my $awk_opts = $delimiter ? "-F$delimiter" : "";

    my $run_awk = Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec(
        "awk $awk_opts '{print NF}' $file | sort | uniq -c",
        { die_on_failure => 1 }
    );
    my $awk_output = $run_awk->out;
    my @col_counts = split("\n", $awk_output);
    die "Expected equal number of columns throughout the file. Got:\n$awk_output" if scalar @col_counts > 1;
    return 1;
}

=head2 check_for_null_characters

    Arg [1]     : $filename
    Description : Checks for null characters in an ASCII text file.
    Returntype  : 1 if file passes check
    Exceptions  : dies if the file contains any null characters

=cut

sub check_for_null_characters {
    my ($filename) = @_;

    my $null_found = 0;
    open(my $fh, "<:encoding(ASCII)", $filename) or die "Cannot open ASCII text file $filename";
    while ( my $line = <$fh> ) {
        if ( $line =~ /\0/ ) {
            $null_found = 1;
            last;
        }
    }
    close $fh or die "Cannot close $filename";

    if ($null_found) {
        die "Unexpected null character found in file: $filename";
    }

    return 1;
}

=head2 get_line_count

    Arg [1]     : $filename
    Description : Return number of lines in $filename
    Returntype  : int

=cut

sub get_line_count {
    my ($file) = @_;

    my $run_wc = Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec(
        "wc -l $file",
        { die_on_failure => 1 }
    );
    my @wc_output = split(/\s+/, $run_wc->out);
    return $wc_output[0];
}

=head2 check_line_counts

    Arg [1]     : $filename
    Arg [2]     : $exp_lines
    Description : Checks that the number of lines in $filename match the expected
                  count ($exp_lines)
    Returntype  : 1 if file passes check
    Exceptions  : throws if file fails check

=cut

sub check_line_counts {
    my ($file, $exp_lines) = @_;

    my $got_line_count = get_line_count($file);
    die "Expected $exp_lines lines, but got $got_line_count: $file" if $exp_lines != $got_line_count;
    return 1;
}


=head2 dump_string_into_file

    Arg [1]     : $dump_file
    Arg [2]     : $str
    Description : Dumps $str into $dump_file
    Exceptions  : Throws if file cannot be opened in write mode

=cut

sub dump_string_into_file {
    my ($dump_file, $str) = @_;

    open( my $fh, '>', $dump_file ) || die "Could not open output file $dump_file";
    print $fh "$str\n";
    close($fh);
}


1;
