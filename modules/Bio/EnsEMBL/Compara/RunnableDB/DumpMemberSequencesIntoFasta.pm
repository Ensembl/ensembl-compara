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

# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta

This runnable dumps all members into one big FASTA file.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'fasta_name'  => 'metazoa.pep', # you should definitely change it
        'split_width' => 72,            # split sequence lines into readable format (set to 0 to disable)
        'idprefixed'  => 1,             # introduce sequence_id as a part of the name (for faster mapping)
    };
}

sub run {
    my $self = shift @_;

    my $fasta_name  = $self->param('fasta_name');
    my $split_width = $self->param('split_width');
    my $idprefixed  = $self->param('idprefixed');


    my $sql = "SELECT m.sequence_id, m.stable_id, m.description, s.sequence " .
                " FROM seq_member m, sequence s " .
                " WHERE m.sequence_id=s.sequence_id ".
                " GROUP BY m.sequence_id ".
                " ORDER BY m.sequence_id, m.stable_id";

    open FASTAFILE, ">$fasta_name"
        or die "Could open $fasta_name for output\n";

    print("writing fasta to file '$fasta_name'\n");

    my $sth = $self->compara_dba()->dbc->prepare( $sql, { 'mysql_use_result' => 1 } );
    $sth->execute();

    my ($sequence_id, $stable_id, $description, $sequence);
    $sth->bind_columns( \$sequence_id, \$stable_id, \$description, \$sequence );

    my $n_seq = 0;
    while( $sth->fetch() ) {
        if ($sequence =~ /^X+$/) {
            print STDERR "$stable_id is all X not dumped\n";
            next;
        }
        $sequence =~ s/(.{$split_width})/$1\n/g if($split_width);
        chomp $sequence;
        my $nameprefix = $idprefixed ? ('seq_id_'.$sequence_id.'_') : '';
        print FASTAFILE ">${nameprefix}${stable_id} $description\n$sequence\n";
        $n_seq++;
    }
    $sth->finish();

    close FASTAFILE;

    my $n_seq_in_file = `grep -c "^>" "$fasta_name"`;
    chomp $n_seq_in_file;
    die "Found $n_seq_in_file sequences in the file instead of $n_seq. Please investigate.\n" if $n_seq ne $n_seq_in_file;
}

1;

