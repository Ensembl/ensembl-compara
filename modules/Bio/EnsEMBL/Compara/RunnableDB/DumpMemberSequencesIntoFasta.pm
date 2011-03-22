#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta

This runnable dumps all members from given source_names into one big FASTA file.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::DumpMemberSequencesIntoFasta;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
        'fasta_name'  => 'metazoa.pep', # you should definitely change it
        'split_width' => 72,            # split sequence lines into readable format (set to 0 to disable)
        'idprefixed'  => 1,             # introduce sequence_id as a part of the name (for faster mapping)
        'removeXed'   => undef,         # do not filter sequences that contain that many X-es consecutively
        'source_names'=> [ 'ENSEMBLPEP','Uniprot/SWISSPROT','Uniprot/SPTREMBL', 'EXTERNALPEP' ],
    };
}

sub run {
    my $self = shift @_;

    my $fasta_name  = $self->param('fasta_name');
    my $split_width = $self->param('split_width');
    my $idprefixed  = $self->param('idprefixed');
    my $removeXed   = $self->param('removeXed');

    my $source_names = join(', ', map { "'$_'" } @{ $self->param('source_names') } );

    my $sql = "SELECT m.sequence_id, m.stable_id, m.description, s.sequence " .
                " FROM member m, sequence s " .
                " WHERE m.source_name in ( $source_names ) ".
                " AND m.sequence_id=s.sequence_id ".
                " GROUP BY m.sequence_id ".
                " ORDER BY m.sequence_id, m.stable_id";

    open FASTAFILE, ">$fasta_name"
        or die "Could open $fasta_name for output\n";

    print("writing fasta to file '$fasta_name'\n");

    my $sth = $self->compara_dba()->dbc->prepare( $sql );
    $sth->execute();

    my ($sequence_id, $stable_id, $description, $sequence);
    $sth->bind_columns( \$sequence_id, \$stable_id, \$description, \$sequence );

    while( $sth->fetch() ) {
        if ($sequence =~ /^X+$/) {
            print STDERR "$stable_id is all X not dumped\n";
            next;
        }
        unless($removeXed and ($sequence =~ /X{$removeXed,}?/)) {
            $sequence =~ s/(.{$split_width})/$1\n/g if($split_width);
            chomp $sequence;
            my $nameprefix = $idprefixed ? ('seq_id_'.$sequence_id.'_') : '';
            print FASTAFILE ">${nameprefix}${stable_id} $description\n$sequence\n";
        }
    }
    $sth->finish();

    close FASTAFILE;
}

1;

