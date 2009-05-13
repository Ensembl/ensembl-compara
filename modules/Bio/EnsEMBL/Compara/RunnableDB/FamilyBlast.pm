package Bio::EnsEMBL::Compara::RunnableDB::FamilyBlast;

use strict;
use FileHandle;
use IPC::Open2;
use IO::Select;

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

    open2(my $from_blast, my $to_blast, 
                "$blastall_executable -d $fastadb -p blastp -e 0.00001 -v $tophits -b 0"
    ) || die "could not execute $blastall_executable, returned error code: $!";

    open2(my $from_parser, my $to_parser, 
               "$blast_parser_executable --score=e --sort=a --ecut=0 --tab=$tabfile -"
    ) || die "could not execute $blast_parser_executable pipe, returned error code: $!";

    my $fasta_listp = $self->param('fasta_list');
    my %matrix_hash = ();

    my $r_all = new IO::Select( $from_blast, $from_parser );
    my $w_all = new IO::Select( $to_blast, $to_parser );

    my $to_blast_no    = fileno $to_blast;
    my $from_blast_no  = fileno $from_blast;
    my $to_parser_no   = fileno $to_parser;
    my $from_parser_no = fileno $from_parser;

    #warn "*** To_blast:    $to_blast_no\n";
    #warn "*** From_blast:  $from_blast_no\n";
    #warn "*** To_parser:   $to_parser_no\n";
    #warn "*** From_parser: $from_parser_no\n";

    do {
        my ($r_ready, $w_ready, $e_ready) = IO::Select->select($r_all, $w_all, undef, undef);
        my %is_ready = map { ((fileno $_) => 1) } (($r_ready ? @$r_ready : ()),($w_ready ? @$w_ready : ()));

            # let's start from the end:
        if($is_ready{fileno $from_parser}) {
            #warn "*** Parser is ready to produce";
            my $parsed_line = <$from_parser>;
            #warn "read the following line: $parsed_line";

            if($parsed_line=~/^(\d+)\s(.*)$/) {
                my ($id, $rest) = ($1, $2);

                $matrix_hash{$id} = $rest;
                #warn "*** There are now ".keys(%matrix_hash). " lines in the matrix description";
            } else {
                die "Got something strange from the blast parser ('$parsed_line'), please investigate";
            }
        }
        if($is_ready{$from_blast_no} and $is_ready{$to_parser_no}) {
            #warn "*** Blast is ready to produce, Parser is ready to read";
            if(my $line = <$from_blast>) {
                #warn "*** Line has been read from Blast";
                print $to_parser $line;
            } else {
                #warn "*** Looks like Blast doesn't want to give us any more data, closing file number $from_blast_no";
                $r_all->remove($from_blast);
                close $from_blast;
                #warn "*** Since there is no data, we are also closing the Parser input, file number $to_parser_no";
                $w_all->remove($to_parser);
                close $to_parser;
            }
        }
        if($is_ready{$to_blast_no}) {
            #warn "*** Blast is ready to read";
            print $to_blast (shift @$fasta_listp);
            #warn "*** One more sequence given to Blast";
            if(! @$fasta_listp) {
                #warn "*** There will be no more sequences to give Blast, closing the file number $to_blast_no";
                $w_all->remove($to_blast);
                close $to_blast;
            }
        }

    } while(scalar(keys %matrix_hash) < $minibatch);

    close $from_parser;

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

