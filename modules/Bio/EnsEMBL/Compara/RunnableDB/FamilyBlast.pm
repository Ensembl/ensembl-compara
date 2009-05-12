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
    my $minibatch               = $self->param('minibatch')   || 1;

    my $sql = qq {
        SELECT m.sequence_id, m.stable_id, m.description, s.sequence
          FROM member m, sequence s
         WHERE s.sequence_id BETWEEN ? AND ?
           AND m.sequence_id=s.sequence_id
      GROUP BY m.sequence_id
      ORDER BY m.sequence_id
    };

    my $sth = $self->dbc->prepare( $sql );
    $sth->execute( $sequence_id, $sequence_id+$minibatch-1 );

    my @fasta_list = ();
    while( my ($seq_id, $stable_id, $description, $seq) = $sth->fetchrow() ) {
        $seq=~ s/(.{72})/$1\n/g;
        chomp $seq;
        push @fasta_list, ">$stable_id $description\n$seq\n";
    }
    $sth->finish();
    $self->dbc->disconnect_when_inactive(1);

    $self->param('fasta_list', \@fasta_list);      # store it in a parameter

    return 1;
}

sub run {
    my $self = shift;

    my $fastadb                 = $self->param('fastadb') || die "'fastadb' is an obligatory parameter, please set it in the input_id hashref";
    my $tabfile                 = $self->param('tabfile') || die "'tabfile' is an obligatory parameter, please set it in the input_id hashref";
    my $minibatch               = $self->param('minibatch') || 1;

    my $blastmat_directory      = $self->param('blastmat_dir')  || '/software/ensembl/compara/blast-2.2.6/data';
    my $blastall_executable     = $self->param('blastall_exec') || '/software/ensembl/compara/blast-2.2.6/blastall';
    my $blast_parser_executable = $self->param('deblast_exec')  || '/nfs/acari/avilella/bin/mcxdeblast';
    my $tophits                 = $self->param('tophits')       || 250;

    $ENV{BLASTMAT} = $blastmat_directory;

    my $fasta_listp = $self->param('fasta_list');

    open2(my $from_blast, my $to_blast, 
                "$blastall_executable -d $fastadb -p blastp -e 0.00001 -v $tophits -b 0"
    ) || die "could not execute $blastall_executable, returned error code: $!";

    print $to_blast @$fasta_listp;
    close $to_blast;

    open2(my $from_parser, my $to_parser, 
               "$blast_parser_executable --score=e --sort=a --ecut=0 --tab=$tabfile -"
    ) || die "could not execute $blast_parser_executable pipe, returned error code: $!";

    while(my $line = <$from_blast>) {
        print $to_parser $line;

        chomp $line; print "FROMBLAST [$line]\n";
    }
    close $from_blast;
    close $to_parser;

    my %matrix_hash = ();
    while(my $parsed_line = <$from_parser>) {
        if($parsed_line=~/^(\d+)\s(.*)$/) {
            my ($id, $rest) = ($1, $2);

            $matrix_hash{$id} = $rest;
        } else {
            die "Got something strange from the blast parser ('$parsed_line'), please investigate";
        }
    }

    $self->param('matrix_hash', \%matrix_hash);        # store it in a parameter
    return 1;
}

sub write_output {
    my $self = shift @_;

    my $matrix_hashp = $self->param('matrix_hash');

    my $sql = "REPLACE INTO mcl_matrix (id, rest) VALUES (?, ?)";
    my $sth = $self->dbc->prepare( $sql );

    while(my($id, $rest) = each %$matrix_hashp) {
        $sth->execute( $id, $rest );
    }
    $sth->finish();

    return 1;
}

1;

