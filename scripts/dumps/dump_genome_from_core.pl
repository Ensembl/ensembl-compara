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

my ($dbname, $host, $port, $user, $pass, $mask, $genome_component, $genome_dump_file, $help);
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
* --user
      username for accessing the core database
* --pass
      password for accessing the core database
* --outfile
      file where the dumped sequence will be stored in fasta format
* --mask
      level of masking of the dumped sequences [soft/hard]. If this option is not defined then the
      sequence will be unmasked.
* --genome-component
      component of a polyploid genome for which sequences should be dumped.
      By default, sequences are dumped for all components of a polyploid genome.

";

GetOptions(
    'core-db|core_db=s'  => \$dbname,
    'host=s'             => \$host,
    'port=s'             => \$port,
    'user=s'             => \$user,
    'pass=s'             => \$pass,
    'mask=s'             => \$mask,
    'genome-component=s' => \$genome_component,
    'outfile=s'          => \$genome_dump_file,
    'help'               => \$help
  );


if ($help) {
    print $desc;
    exit(0);
}

if ( defined $mask && $mask !~ /soft|hard/ ) {
    die "ERROR: '--mask' has to be either 'soft' or 'hard'\n"
}

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new( -user   => $user,
                                               -pass   => $pass,
                                               -dbname => $dbname,
                                               -host   => $host,
                                               -port   => $port,
                                               -driver => 'mysql');

my $slice_adaptor = $dba->get_SliceAdaptor();

my $slices;
if (defined $genome_component) {
    # validate the genome component, if specified
    my @core_db_components = @{$dba->get_GenomeContainer->get_genome_components()};
    if (!@core_db_components) {
        die "ERROR: invalid option '--genome-component' - no components found in core database '$dbname'\n";
    }
    elsif (! grep { $_ eq $genome_component } @core_db_components) {
        die "ERROR: genome component '$genome_component' not found in core database '$dbname'\n";
    }
    # If the core has passed the PolyploidAttribs datacheck,
    # only top-level regions will have genome components.
    $slices = $slice_adaptor->fetch_all_by_genome_component($genome_component);
} else {
    $slices = $slice_adaptor->fetch_all("toplevel");
}

open(my $filehandle, '>', $genome_dump_file) or die "can't open $genome_dump_file for writing\n";


# create a fasta serialiser that defines the seq_region_name() as fasta header
my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new(
    $filehandle,
    sub{
        my $slice = shift;
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

close($filehandle) or die "can't close $genome_dump_file\n";
