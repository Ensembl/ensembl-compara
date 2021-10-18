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

=head1 NAME

dump_gene_set_from_core.pl

=head1 DESCRIPTION

This script dumps the canonical peptide of all protein coding genes from a core database.

=head1 SYNOPSIS

    perl dump_gene_set_from_core.pl --core-db <COREDB> --host <HOST> --port <PORT> --outfile <OUTFILE>

=head1 EXAMPLES

    perl dump_gene_set_from_core.pl --core-db bos_taurus_core_106_12 \
        --host mysql-ens-vertannot-staging --port 4573 --outfile $HOME/bos_taurus_canon_pep.fasta

=head1 OPTIONS

=over

=item B<-core-db> <core_db>, B<-core_db> <core_db>

Core database name storing the genome sequence to be dumped.

=item B<-host> <host>

Server hosting the core database.

=item B<-port> <port>

Port for the host database.

=item B<-outfile> <outfile>

File where the dumped sequence will be stored (in fasta format).

=item B<-h[elp]>

Print usage information.

=back

=cut
use strict;
use warnings;


use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::Seq;
use Bio::SeqIO;

use Getopt::Long;
use Pod::Usage;

my ($dbname, $host, $port, $gene_set_dump_file, $help);

GetOptions(
    'core-db|core_db=s' => \$dbname,
    'host=s'            => \$host,
    'port=s'            => \$port,
    'outfile=s'         => \$gene_set_dump_file,
    'h|help'            => \$help
);

pod2usage(1) if $help;
unless ($dbname and $host and $port and $gene_set_dump_file) {
    pod2usage(1);
}

my $dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(
    -user   => 'ensro',
    -dbname => $dbname,
    -host   => $host,
    -port   => $port,
    -driver => 'mysql',
);

my $genes = $dba->get_GeneAdaptor()->fetch_all_by_biotype('protein_coding');

my $seq_out = Bio::SeqIO->new( -file => ">$gene_set_dump_file", -format => 'Fasta');

print "Found ", scalar(@$genes), " genes.\n";

foreach my $gene (@$genes) {
    my $can_transcript = $gene->canonical_transcript();

    if ( $can_transcript->translation() ) {
        my $pep = $can_transcript->translate();
        $seq_out->write_seq($pep);
    }
}
