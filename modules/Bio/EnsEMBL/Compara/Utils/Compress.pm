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

=head1 NAME

Bio::EnsEMBL::Compara::Utils::Compress

=head1 DESCRIPTION

Methods to compress / uncompress data the same way MySQL would do it with COMPRESS() and UNCOMPRESS().

compress_to_mysql() uses the external program "zopfli" if it is available (L<https://github.com/google/zopfli>)

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::Utils::Compress;

use strict;
use warnings;

use Compress::Zlib;
use DBI qw(:sql_types);
use File::Temp qw/tempfile/;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Bio::EnsEMBL::Compara::Utils::RunCommand;

our $zopfli_path = `which zopfli 2> /dev/null`;
chomp $zopfli_path;


=head2 uncompress_from_mysql

  Arg [1]       : $compressed_data: the data to be uncompressed
  Example       : my $stringified_exon_boundaries_data = uncompress_from_mysql($compressed_data);
  Description   : Uncompress some data that is formatted like MySQL's COMPRESS()
  ReturnType    : blob $uncompressed_data
  Exceptions    : If $compressed_data is missing
  Caller        : General

=cut

sub uncompress_from_mysql {
    my $compressed_data = shift;

    throw('$compressed_data must be given') unless defined $compressed_data;

    # MySQL-style compression -UNCOMPRESS()-
    # The first 4 bytes are the length of the text in little-endian
    my $uncompressed_data = Compress::Zlib::uncompress( substr($compressed_data,4) );
    return $uncompressed_data;
}


=head2 compress_to_mysql

  Arg [1]       : $data: the data to be compressed
  Example       : my $compressed_data = compress_to_mysql($stringified_exon_boundaries_data);
  Description   : Compress some data in a format that MySQL can understand, i.e.:
                   - the first 4 bytes are the length of the uncompressed data
                   - data compressed following the zlib algorithm and format
                  The returned string is structured as MySQL's COMPRESS() would do it, which
                  enables UNCOMPRESS().
  ReturnType    : blob $compressed_data
  Exceptions    : If $data is missing
  Caller        : General

=cut

sub compress_to_mysql {
    my $data = shift;

    throw('$data must be given') unless defined $data;

    # Compress with zopfli if available
    my $zlib_data;
    if ($zopfli_path) {
        my ($fh, $filename) = tempfile(UNLINK => 1);
        print $fh $data;
        close($fh);
        Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec([$zopfli_path, '--zlib', $filename], { die_on_failure => 1 });
        $zlib_data = slurp($filename.'.zlib');
        unlink $filename.'.zlib';
    } else {
        $zlib_data = Compress::Zlib::compress($data, Z_BEST_COMPRESSION)
    }

    # MySQL-style compression -COMPRESS()-
    # The first 4 bytes are the length of the text in little-endian
    my $compressed_data = pack('V', length($data)).$zlib_data;
    return $compressed_data;
}


1;
