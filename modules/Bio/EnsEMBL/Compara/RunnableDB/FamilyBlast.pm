package Bio::EnsEMBL::Compara::RunnableDB::FamilyBlast;

use strict;
use FileHandle;
use IPC::Open2;

use Bio::EnsEMBL::Hive::Process;
our @ISA = qw(Bio::EnsEMBL::Hive::Process);

sub param {
    my $self = shift @_;

    unless($self->{'_param_hash'}) {
        $self->{'_param_hash'} = { %{eval($self->parameters())}, %{eval($self->input_id())} };
    }

    my $param_name = shift @_;
    if(@_) { # If there is a value (even if undef), then set it!
        $self->{'_param_hash'}{$param_name} = shift @_;
    }

    return $self->{'_param_hash'}{$param_name};
}

sub fetch_input {
    my $self = shift @_;

    my $sequence_id             = $self->param('sequence_id') || die "'sequence_id' is an obligatory parameter, please set it in the input_id hashref";

    my $sql = qq {
        SELECT m.stable_id, m.description, s.sequence
          FROM member m, sequence s
         WHERE s.sequence_id = ?
           AND m.sequence_id=s.sequence_id
      GROUP BY m.sequence_id
    };

    my $sth = $self->dbc->prepare( $sql );
    $sth->execute( $sequence_id );

    if( my ($stable_id, $description, $seq) = $sth->fetchrow() ) {
        $seq=~ s/(.{72})/$1\n/g;
        chomp $seq;
        $self->param('fasta', ">$stable_id $description\n$seq\n");
    } else {
        die "Problem fetching the sequence with sequence_id='$sequence_id' from the DB";
    }
    $sth->finish();
    $self->dbc->disconnect_if_idle();

    return 1;
}

sub run {
    my $self = shift;

    my $fastadb                 = $self->param('fastadb') || die "'fastadb' is an obligatory parameter, please set it in the input_id hashref";
    my $tabfile                 = $self->param('tabfile') || die "'tabfile' is an obligatory parameter, please set it in the input_id hashref";

    my $blastmat_directory      = $self->param('blastmat_dir')  || '/software/ensembl/compara/blast-2.2.6/data';
    my $blastall_executable     = $self->param('blastall_exec') || '/software/ensembl/compara/blast-2.2.6/blastall';
    my $blast_parser_executable = $self->param('deblast_exec')  || '/nfs/acari/avilella/bin/mcxdeblast';
    my $tophits                 = $self->param('tophits')       || 250;

    $ENV{BLASTMAT} = $blastmat_directory;

    open2(my $from_blast, my $to_blast, "$blastall_executable -d $fastadb -p blastp -e 0.00001 -v $tophits -b 0")
        || die "could not execute $blastall_executable, returned error code: $!";

    print $to_blast $self->param('fasta');
    close $to_blast;

    open2(my $from_parser, my $to_parser, "$blast_parser_executable --score=e --sort=a --ecut=0 --tab=$tabfile -")
        || die "could not execute $blast_parser_executable, returned error code: $!";

    while(my $blast_output = <$from_blast>) { # isn't there a direct way of coupling file handles?
        print $to_parser $blast_output;
    }
    close $from_blast;
    close $to_parser;

    my $parsed_line = <$from_parser>;
    close $from_parser;

    if($parsed_line=~/^(\d+)\s(.*)$/) {
        my ($id, $rest) = ($1, $2);

        my $sequence_id = $self->param('sequence_id');
        if($id eq $sequence_id) {
            $self->param('rest', $rest);
        } else {
            die "sequence_id='$sequence_id', but the blast parser returned '$id', please investigate";
        }
    } else {
        die "Got something wrong from the blast parser ('$parsed_line'), please investigate";
    }

    return 1;
}

sub write_output {
    my $self = shift @_;

    my $sequence_id             = $self->param('sequence_id');
    my $rest                    = $self->param('rest');

    my $sql = "REPLACE INTO mcl_matrix (id, rest) VALUES (?, ?)";
    my $sth = $self->dbc->prepare( $sql );
    $sth->execute( $sequence_id, $rest );
    $sth->finish();
    $self->dbc->disconnect_if_idle();

    return 1;
}

1;

