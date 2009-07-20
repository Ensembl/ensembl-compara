#!/usr/local/bin/perl -w

# Produce the matrix file necessary to run the MCL
#
# Restriction from mcxassemble:
# please only run this on the farm that has 'hugemem' queue (currently it is farm-1, but check 'bqueues' to be sure).
# Otherwise you will have to (re)start the assembling binary directly on turing.

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub get_count_max_from_tabfile {
    my $filename = shift @_;

    my ($count, $max) = (0, 0, 0);
    open(TABFILE, "<$filename");
    while(my $line = <TABFILE>) {
        my ($ind, $name) = split(/\s+/, $line);
        if($ind>$max) { $max = $ind; }
        if($ind) { $count++; }
    }
    return ($count, $max);
}

sub get_count_max_from_db {
    my $dbc = shift @_;

    my $sth = $dbc->prepare( "SELECT count(sequence_id), max(sequence_id) FROM sequence" );
    $sth->execute();
    if( my ($count, $max) = $sth->fetchrow()) {
        return ($count, $max);
    } else {
        die "Could not find the number of sequences in the DB";
    }
}

sub dump_mcl_matrix_into_file {
    my ($dbc, $outfile, $expected_size, $max, $offset, $force) = @_;

    my $check_sth = $dbc->prepare( "SELECT count(*) FROM mcl_matrix WHERE id BETWEEN ? AND ?" );
    $check_sth->execute($offset, $max+$offset);
    if( my ($actual_size) = $check_sth->fetchrow()) {
        $check_sth->finish();
        if( $actual_size==$expected_size or $force ) {
            my $dump_sth = $dbc->prepare( "SELECT id-?, rest FROM mcl_matrix WHERE id BETWEEN ? AND ?", { "mysql_use_result" => 1} );
            $dump_sth->execute($offset, $offset, $max+$offset);
            open(OUT, ">$outfile");
            while( my ($id, $rest) = $dump_sth->fetchrow() ) {
                print OUT "$id $rest\n";
            }
            close OUT;
            $dump_sth->finish();
        } else {
            die "The sizes of the mcl_matrix in the DB ($actual_size) and the tab_file ($expected_size) do not match, please investigate";
        }
    } else {
        die "Problem fetching the size of the mcl_matrix from the DB";
    }
}

my $asm_executable = '/nfs/team71/analysis/lg4/work/ensembl-compara_HEAD/scripts/family/mcxassemble.sh.tcx';

my ($tab_file, $nameprefix);
my $force  = 0;
my $offset = 0;
my $dbconn = { -user => 'ensro', -port => 3306 };

GetOptions(
            # connection parameters:
        'dbhost=s' => \$dbconn->{-host},
        'dbport=i' => \$dbconn->{-port},
        'dbuser=s' => \$dbconn->{-user},
        'dbpass=s' => \$dbconn->{-pass},
        'dbname=s' => \$dbconn->{-dbname},

            # obligatory parameters:
	   'nameprefix=s' => \$nameprefix,

            # optional parameters:
       'offset=i'     => \$offset,
	   'tab=s'        => \$tab_file,
       'aexec=s'      => \$asm_executable,
       'force!'       => \$force, # ignore the condition that number of lines in the matrix should be equal to number of lines in the .tab file
);

unless( $nameprefix ) {
    die "Please specify nameprefix";
}

my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%$dbconn) || die "Could not create the DBAdaptor";
my $dbc = $dba->dbc();

my ($count, $max) = $tab_file
    ? get_count_max_from_tabfile($tab_file)
    : get_count_max_from_db($dbc);

dump_mcl_matrix_into_file($dbc, "${nameprefix}.unsorted", $count, $max, $offset, $force);

system("sort -n ${nameprefix}.unsorted >${nameprefix}.raw");
unlink $nameprefix.'.unsorted';

$count++;    # EXPERIMENTAL: actually having 1..N elements and not wanting to re-number, we pretend to have 0..N

open(HDR, ">${nameprefix}.hdr");
print HDR "(mclheader\nmcltype matrix\ndimensions ${count}x${count}\n)\n";
close HDR;

if($tab_file) { # EXPERIMENTAL: hopefully MCL is not interested in this .tab file so we can skip its creation
    system("cp $tab_file ${nameprefix}.tab");
}

if(my $asm_error = system($asm_executable, $nameprefix)) {
    die "matrix assembler executable '$asm_executable' died with error code: $asm_error";
}

