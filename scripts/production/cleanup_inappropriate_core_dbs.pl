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

use warnings;
use strict;

=head1 NAME

cleanup_inappropriate_core_dbs.pl

=head1 DESCRIPTION

This script will assess whether a core db on a compara server should be present or not.

There are options to check for each division, different releases, different hosts and with dry-run

=head1 SYNOPSIS

 perl cleanup_inappropriate_core_dbs.pl
    --host mysql-ens-vertannot-staging
    --release ${CURR_ENSEMBL_RELEASE}
    --division ${COMPARA_DIV}
    --dry_run

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--host host]>

(Optional) The server host mysql-ens-vertannot-staging is default if not specified.

=item B<[--release CURR_ENSEMBL_RELEASE]>

(Optional) Ensembl release if not specified looks to environment variable ${CURR_ENSEMBL_RELEASE}.

=item B<[--division COMPARA_DIV]>

(Optional) The division of interest - if not specified looks to environment variable ${COMPARA_DIV}.

=item B<[--dry_run]>

(Optional) If provided the checks will print, but no databases will be removed.

=back

=cut

use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::Registry;
use Getopt::Long;
use JSON qw( decode_json );
use Pod::Usage;


my ($help, $dry_run);
my $host     = "mysql-ens-vertannot-staging";
my $release  = $ENV{'CURR_ENSEMBL_RELEASE'};
my $division = $ENV{'COMPARA_DIV'};

GetOptions(
    "help|?"     => \$help,
    "host:s"     => \$host,
    "release:i"  => \$release,
    "division:s" => \$division,
    "dry_run!"   => \$dry_run
) or pod2usage(-verbose => 2);
pod2usage(-exitvalue => 0, -verbose => 2) if $help;

my $allowed_species = $ENV{'ENSEMBL_ROOT_DIR'} . "/ensembl-compara/conf/" . $division . "/allowed_species.json";

my $port    = Bio::EnsEMBL::Compara::Utils::Registry::get_port($host);
my $rw_user = Bio::EnsEMBL::Compara::Utils::Registry::get_rw_user($host);
my $rw_pwd  = Bio::EnsEMBL::Compara::Utils::Registry::get_rw_pass($host);

my $server = "mysql://" . $rw_user . ":" . $rw_pwd . "\@" . $host . ":" . $port;
Bio::EnsEMBL::Registry->load_registry_from_url($server . "/" . $release);
my @allowed_species = read_allowed_species( $allowed_species );

# Species that overlap between divisions that are expected
my @ignore_species = qw(
    caenorhabditis_elegans
    drosophila_melanogaster
    saccharomyces_cerevisiae
);

my @inappropriate_cores;
foreach my $species ( @allowed_species ) {
    next if $species ~~ @ignore_species;
    my $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors( $species, "core" );
    foreach my $dba ( @$dbas ) {
        my $production_name = $dba->get_MetaContainer->get_production_name;
        my $div = $dba->get_MetaContainer->get_division;
        if ( $production_name ne $species or $div !~ /$division/i ) {
            print "not ok $species\n";
            push @inappropriate_cores, $dba->dbc->dbname;
            drop_inappropriate_db($dba->dbc->dbname, $rw_user, $rw_pwd, $host, $port, $dry_run);
            $dbas = Bio::EnsEMBL::Registry->get_all_DBAdaptors( $species, "core" );
        }
        else {
            print "ok $species\n";
        }
    }
}
print "\n--------------------------------------\n";
print "SUMMMARY";
print "\n--------------------------------------\n";
print "Cores to be removed:\n\n";
print join("\n", @inappropriate_cores), "\n\n";

sub read_allowed_species {
    my $file_name = shift;
    my $json_str;
    {
        local $/ = undef;
        open( my $fh, '<', $file_name ) or die ( "Could not open file $file_name" );
        $json_str = <$fh>;
        close( $fh ) or die ( "Could not close file $file_name" );
    }
    my @species = @{ decode_json($json_str) };
    return @species;
}

sub drop_inappropriate_db {
    my ($dbname, $rw_user, $rw_pwd, $host, $port, $dry_run) = @_;
    my $dsn = "DBI:mysql:database=" . $dbname . ";host=$host" . ";port=$port";
    my $dbh = DBI->connect( $dsn, $rw_user, $rw_pwd ) || die "Could not connect to MySQL server";
    my $sql = "DROP DATABASE $dbname;";
    unless ( $dry_run ) {
        my $sth = $dbh->prepare($sql);
        $sth->execute();
    }
}

1;
