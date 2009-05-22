package Bio::EnsEMBL::Compara::RunnableDB::FamilyBlast;

use strict;
use FileHandle;

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

sub load_fasta_sequences_from_db {
    my ($self, $sequence_id, $minibatch) = @_;

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

    return \@fasta_list;
}

sub load_name2index_mapping_from_db {
    my ($self) = @_;

    my $sql = qq {
        SELECT sequence_id, stable_id
          FROM member
         WHERE sequence_id
      GROUP BY sequence_id
    };

    my $sth = $self->dbc->prepare( $sql );
    $sth->execute();

    my %name2index = ();
    while( my ($seq_id, $stable_id) = $sth->fetchrow() ) {
        $name2index{$stable_id} = $seq_id;
    }
    $sth->finish();
    $self->dbc->disconnect_when_inactive(1);

    return \%name2index;
}

sub load_name2index_mapping_from_file {
    my ($self, $filename) = @_;

    my %name2index = ();
    open(MAPPING, "<$filename");
    while(my $line = <MAPPING>) {
        if($line=~/^(\d+)\s+(\w+)/) {
            $name2index{$2} = $1;
        }
    }
    close MAPPING;

    return \%name2index;
}

sub fetch_input {
    my $self = shift @_;

    my $sequence_id             = $self->param('sequence_id') || die "'sequence_id' is an obligatory parameter, please set it in the input_id hashref";
    my $minibatch               = $self->param('minibatch')   || 1;
    my $tabfile                 = $self->param('tabfile');

    $self->param('fasta_list', $self->load_fasta_sequences_from_db($sequence_id, $minibatch));

    $self->param('name2index', $tabfile
        ? $self->load_name2index_mapping_from_file($tabfile)
        : $self->load_name2index_mapping_from_db($tabfile)
    );

    return 1;
}

sub parse_blast_table_into_matrix_hash {
    my ($self, $filename) = @_;

    my $name2index = $self->param('name2index');

    my %matrix_hash  = ();

    my $curr_name    = '';
    my $curr_index   = 0;
    my @dist_accu    = ();

    open(BLASTTABLE, "<$filename");
    while(my $line = <BLASTTABLE>) {

        if($line=~/^#/) {
            if($line=~/^#\s+BLASTP/) {
                if($curr_index) {
                    $matrix_hash{$curr_index} = join(' ', @dist_accu, '$'); # flush the buffer
                    @dist_accu = ();
                }
            } elsif($line=~/^#\s+Query:\s+(\w+)/) {
                $curr_name  = $1;
                $curr_index = $name2index->{$curr_name};
            }
        } else {
            my ($qname, $hname, $identity, $align_length, $mismatches, $gap_openings, $qstart, $qend, $hstart, $hend, $evalue, $bitscore)
                = split(/\s+/, $line);

            my $hit_index = $name2index->{$hname};
                # you MUST be explicitly numeric here:
            my $distance  = ($evalue != 0) ? -log($evalue)/log(10) : 200;

            push @dist_accu, $hit_index.':'.$distance;
        }
    }
    close BLASTTABLE;
    $matrix_hash{$curr_index} = join(' ', @dist_accu, '$'); # flush the buffer

    return \%matrix_hash;
}

sub run {
    my $self = shift @_;

    my $fastadb                 = $self->param('fastadb')   || die "'fastadb' is an obligatory parameter, please set it in the input_id hashref";
    my $minibatch               = $self->param('minibatch') || 1;

    my $blastmat_directory      = $self->param('blastmat_dir')  || '/software/ensembl/compara/blast-2.2.6/data';
    my $blastall_executable     = $self->param('blastall_exec') || '/software/ensembl/compara/blast-2.2.6/blastall';
    my $evalue_limit            = $self->param('evalue_limit')  || 0.00001;
    my $tophits                 = $self->param('tophits')       || 250;
    my $debug                   = $self->param('debug')         || 0;

    my $fasta_listp             = $self->param('fasta_list'); # set by fetch_input()

    $ENV{BLASTMAT} = $blastmat_directory;

    my $interfile = '/tmp/family_blast.out.'.$$;    # looks like inevitable evil (tried many hairy alternatives and failed)

    open( BLAST, "| $blastall_executable -d $fastadb -p blastp -e $evalue_limit -v $tophits -m 9 -o $interfile")
        || die "could not execute $blastall_executable, returned error code: $!";

    print BLAST @$fasta_listp;
    close BLAST;

    my $matrix_hash = $self->parse_blast_table_into_matrix_hash($interfile);

    if(scalar(keys %$matrix_hash)<$minibatch) {
        die "According to our parser the table file generated by Blastp is incomplete, please investigate";
    }

    unless($debug) {
        unlink $interfile;
        $self->param('matrix_hash', $matrix_hash);        # store it in a parameter
    }

    return 1;
}

sub write_output {
    my $self = shift @_;

    if(my $matrix_hash = $self->param('matrix_hash')) {

# FIXME!!! Restore this line back to mcl_matrix !!!
        #my $sql = "REPLACE INTO mcl_matrix (id, rest) VALUES (?, ?)";
        my $sql = "REPLACE INTO mcl_matrix_test (id, rest) VALUES (?, ?)";

        my $sth = $self->dbc->prepare( $sql );

        while(my($id, $rest) = each %$matrix_hash) {
            $sth->execute( $id, $rest );
        }
        $sth->finish();
    }

    return 1;
}

1;

