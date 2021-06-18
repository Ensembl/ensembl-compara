#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use strict;
use warnings;


use Bio::EnsEMBL::PaddedSlice;
use Bio::EnsEMBL::Utils::IO::FASTASerializer;
use Bio::EnsEMBL::DBSQL::DBAdaptor;

use Getopt::Long;

my ($dbname, $host, $port, $mask, $genome_dump_file, $help);
my $desc = "
This script dumps all toplevel sequences from a core database and stores them in fasta file.
The sequences can be unmasked, soft masked or hard masked.

USAGE dump_genome_from_core.pl [-mask] -core-db COREDB -host HOST -port PORT -outfile OUTFILE

Options:
* --core-db
      the core database name storing the genome sequence to be dumped
* --host
      server hosting the core database
* --port
      port for the host database
* --outfile
      file where the dumped sequence will be stored in fasta format
* --mask
      level of masking of the dumped sequences [soft/hard]. If this option is not defined then the
      sequence will be unmasked.
";

GetOptions(
    'core-db|core_db=s' => \$dbname,
    'host=s'            => \$host,
    'port=s'            => \$port,
    'mask=s'            => \$mask,
    'outfile=s'         => \$genome_dump_file,
    'help'              => \$help
  );


if ($help) {
    print $desc;
    exit(0);
}

if ( defined $mask && $mask !~ /soft|hard/ ) {
    die "ERROR: '--mask' has to be either 'soft' or 'hard'\n"
}

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new( -user   => 'ensro',
                                               -dbname => $dbname,
                                               -host   => $host,
                                               -port   => $port,
                                               -driver => 'mysql');

my $slices = $dba->get_SliceAdaptor->fetch_all("toplevel");

open(my $filehandle, '>', $genome_dump_file) or die "can't open $genome_dump_file for writing\n";


# create a fasta serialiser that define the seq_region_name() as fasta header
my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
    $filehandle,
    sub{
        my $slice = shift;
        $slice->seq_region_name();
        return $slice->seq_region_name();
    }
);

# dump the slices
foreach my $slice (@$slices){
    if (defined $mask && $mask eq "soft"){
        $slice = $slice->get_repeatmasked_seq(undef, 1);
    }
    elsif (defined $mask && $mask eq "hard"){
        $slice = $slice->get_repeatmasked_seq();
    }
    my $padded_slice = Bio::EnsEMBL::PaddedSlice->new(-SLICE => $slice);
    $serializer->print_Seq($padded_slice);
}
