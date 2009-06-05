#!/usr/local/bin/perl -w

# Produce the matrix file necessary to run the MCL
#
# Restriction from mcxassemble:
# please only run this on the farm that has 'hugemem' queue (currently it is farm-1, but check 'bqueues' to be sure).
# Otherwise you can (re)start the assembling binary directly on turing.

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

sub dump_mcl_matrix_into_file {
    my ($dbc, $outfile, $expected_size, $force) = @_;

    my $check_sth = $dbc->prepare( "SELECT count(*) FROM mcl_matrix" );
    $check_sth->execute();
    if( my ($actual_size) = $check_sth->fetchrow()) {
        $check_sth->finish();
        if( $actual_size==$expected_size or $force ) {
            my $dump_sth = $dbc->prepare ( "SELECT id, rest FROM mcl_matrix", { "mysql_use_result" => 1} );
            $dump_sth->execute();
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
my $force = 0;
my $dbconn = { -user => 'ensro', -port => 3306 };

GetOptions(
            # connection parameters:
        'dbhost=s' => \$dbconn->{-host},
        'dbport=i' => \$dbconn->{-port},
        'dbuser=s' => \$dbconn->{-user},
        'dbpass=s' => \$dbconn->{-pass},
        'dbname=s' => \$dbconn->{-dbname},

            # obligatory parameters:
	   'tab=s'        => \$tab_file,
	   'nameprefix=s' => \$nameprefix,

            # optional parameters:
       'aexec=s'      => \$asm_executable,
       'force!'       => \$force, # ignore the condition that number of lines in the matrix should be equal to number of lines in the .tab file
);

unless( $tab_file && $nameprefix ) {
    die "Please specify tab_file and nameprefix parameters";
}

my $dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%$dbconn)
        || die "Could not create the DBAdaptor";

my $tab_size = `wc -l $tab_file | cut -d ' ' -f 1`; chomp $tab_size;

dump_mcl_matrix_into_file($dba->dbc(), "${nameprefix}.unsorted", $tab_size, $force);

system("sort -n ${nameprefix}.unsorted >${nameprefix}.raw");

$tab_size++;    # EXPRETIMENTAL: actually having 1..N elements and not wanting to re-number, we pretend to have 0..N

open(HDR, ">${nameprefix}.hdr");
print HDR "(mclheader\nmcltype matrix\ndimensions ${tab_size}x${tab_size}\n)\n";
close HDR;

system("cp $tab_file ${nameprefix}.tab");

if(my $asm_error = system($asm_executable, $nameprefix)) {
    die "matrix assembler executable '$asm_executable' died with error code: $asm_error";
}

