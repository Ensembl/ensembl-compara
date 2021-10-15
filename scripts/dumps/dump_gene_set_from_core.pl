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


use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::Seq;
use Bio::SeqIO;

use Getopt::Long;

my ($dbname, $host, $port, $gene_set_dump_file, $help);
my $desc = "
This script dumps the canonical peptide of all protein coding genes from a core db

USAGE dump_gene_set_from_core.pl -core-db COREDB -host HOST -port PORT -outfile OUTFILE

Options:
* --core-db
      the core database name storing the genome sequence to be dumped
* --host
      server hosting the core database
* --port
      port for the host database
* --outfile
      file where the dumped sequence will be sored in fasta format
";

GetOptions(
    'core-db=s'  => \$dbname,
    'host=s'    => \$host,
    'port=s'    => \$port,
    'outfile=s' => \$gene_set_dump_file,
    'help'      => \$help
  );

if ($help) {
  print $desc;
  exit(0);
}

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new( -user   => 'ensro',
                                               -dbname => $dbname,
                                               -host   => $host,
                                               -port   => $port,
                                               -driver => 'mysql');

my $genes = $dba->get_GeneAdaptor()->fetch_all_by_biotype('protein_coding');

## create a Fasta seqIO object to store the sequences
my $seq_out = Bio::SeqIO->new( -file => ">$gene_set_dump_file", -format => 'Fasta');

# dump the canonical peptide to file
print scalar(@$genes) . "\n";

foreach my $gene (@$genes){
    my $can_transcript = $gene->canonical_transcript ();
    if ( $can_transcript->translation() ) {
        my $pep = $can_transcript->translate();
        $seq_out->write_seq($pep);
    }
}
