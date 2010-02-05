#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use FileHandle;
use IPC::Open2;

sub fetch_fasta {
    my ($dba, $sequence_id, $filehandle) = @_;

    my $sql = qq {
        SELECT m.stable_id, m.description, s.sequence
          FROM member m, sequence s
         WHERE s.sequence_id = ?
           AND m.sequence_id=s.sequence_id
      GROUP BY m.sequence_id
    };

    my $sth = $dba->dbc->prepare( $sql );
    $sth->execute( $sequence_id );

    if( my ($stable_id, $description, $seq) = $sth->fetchrow() ) {
        $seq=~ s/(.{72})/$1\n/g;
        chomp $seq;
        print $filehandle ">$stable_id $description\n$seq\n";
    } else {
        die "Problem fetching the sequence from the DB";
    }

    $sth->finish();
}

sub store_line {
    my ($dba, $line) = @_;

    $line=~/^(\d+)\s(.*)$/;
    my ($id, $rest) = ($1, $2);

    my $sql = "REPLACE INTO mcl_matrix (id, rest) VALUES (?, ?)";
    my $sth = $dba->dbc->prepare( $sql );
    $sth->execute( $id, $rest );
    $sth->finish();
}

my $blastmat_directory      = '/software/ensembl/compara/blast-2.2.6/data';
my $blastall_executable     = '/software/ensembl/compara/blast-2.2.6/blastall';
my $blast_parser_executable = '/nfs/acari/avilella/bin/mcxdeblast';
my $tophits                 = 250;
my $batch_size              = 1;

my ($start_sequence_id, $fastadb, $tab_file);
my $dbconn = { -user => 'ensro', -port => 3306 };

GetOptions(
            # connection parameters:
        'dbhost=s' => \$dbconn->{-host},
        'dbport=i' => \$dbconn->{-port},
        'dbuser=s' => \$dbconn->{-user},
        'dbpass=s' => \$dbconn->{-pass},
        'dbname=s' => \$dbconn->{-dbname},

            # obligatory parameters:
       's=i'          => \$start_sequence_id,
	   'fastadb=s'    => \$fastadb,
	   'tab=s'        => \$tab_file,

            # optional parameters:
       'n=i'          => \$batch_size,
       'baexec=s'     => \$blastall_executable,
       'bpexec=s'     => \$blast_parser_executable,
       'bmdir=s'      => \$blastmat_directory,
       'tophits=i'    => \$tophits,
);

unless( $start_sequence_id and $fastadb and $tab_file ) {
    die "Please specify start_sequence_id, fastadb and tab_file parameters";
}

my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%$dbconn)
        || die "Could not create the DBAdaptor";

# set this in the script for all subprocesses (they should inherit the value)
$ENV{BLASTMAT} = $blastmat_directory;

foreach my $sequence_id ($start_sequence_id..($start_sequence_id+$batch_size-1)) {

    open2(my $from_blast, my $to_blast, "$blastall_executable -d $fastadb -p blastp -e 0.00001 -v $tophits -b 0")
        || die "could not execute $blastall_executable, returned error code: $!";

    fetch_fasta($dba, $sequence_id, $to_blast);
    close $to_blast;

    open2(my $from_parser, my $to_parser, "$blast_parser_executable --score=e --sort=a --ecut=0 --tab=$tab_file -")
        || die "could not execute $blast_parser_executable, returned error code: $!";

    while(my $blast_output = <$from_blast>) { # isn't there a direct way of coupling file handles?
        print $to_parser $blast_output;
    }
    close $from_blast;
    close $to_parser;

    my $parsed_line = <$from_parser>;
    close $from_parser;

    store_line($dba, $parsed_line);
}

