#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


=head1 NAME

copy_all_core_databases.pl

=head1 DESCRIPTION

This script automatically discovers the core databases available on the
staging server and submits a job to copy them onto the vertannot-staging
server.

The script doesn't do the copy itself but uses the Ensembl Production
REST API. For convenience you will need a checkout of ensembl-prodinf-core
under $ENSEMBL_CVS_ROOT_DIR.

It can work without any arguments if your environment is set properly,
i.e. ENSEMBL_CVS_ROOT_DIR and ENSADMIN_PSW are defined, otherwise the
options are listed below.

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[-s|--source_server_url]>

Where to get the databases from. Defaults to mysql-ens-sta-1

=item B<[-s|--target_server_url]>

Where to copy the databases to. Defaults to mysql-vertannot-staging-ensadmin
See L<--ensadmin_psw> to define the ensadmin password

=item B<[-u|--endpoint_uri]>

The URI of the Ensembl Production Self-Service REST API. Defaults to
http://ens-prod-1.ebi.ac.uk:8000/dbcopy/

=item B<[-c|--db_copy_client]>

Path to the db_copy_client.py script. Defaults to
${ENSEMBL_CVS_ROOT_DIR}/ensembl-prodinf-core/ensembl_prodinf/db_copy_client.py

=item B<[--ensadmin_psw this_is_a_secret_password]>

Password for the ensadmin MySQL user. Defaults to $ENV{ENSADMIN_PSW}

=back

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use Bio::EnsEMBL::Registry;


## Command-line options
my ($db_copy_client, $endpoint_uri, $source_server_url, $target_server_url, $ensadmin_psw, $help);

GetOptions(
        's|source_server_url'   => \$source_server_url,
        't|target_server_url'   => \$target_server_url,
        'u|endpoint_uri'        => \$endpoint_uri,
        'c|db_copy_client'      => \$db_copy_client,
        'p|ensadmin_psw=s'      => \$ensadmin_psw,

        'h|help'                => \$help,
);


if ($help) {
    pod2usage({-exitvalue => 0, -verbose => 2});
}

if (not $db_copy_client) {
    if (not $ENV{ENSEMBL_CVS_ROOT_DIR}) {
        die "--db_copy_client is not given, and cannot find \$ENSEMBL_CVS_ROOT_DIR in the environment\n";
    }
    $db_copy_client = $ENV{ENSEMBL_CVS_ROOT_DIR}.'/ensembl-prodinf-core/ensembl_prodinf/db_copy_client.py';
}
die "'$db_copy_client' is not executable (or doesn't exist ?)\n" unless -x $db_copy_client;

if (not $target_server_url) {
    if (not $ensadmin_psw) {
        if (not $ENV{ENSADMIN_PSW}) {
            die "--ensadmin_psw is not given, and cannot find \$ENSADMIN_PSW in the environment. The password is needed to build the default target URL.\n";
        }
        $ensadmin_psw = $ENV{ENSADMIN_PSW};
    }
}

$endpoint_uri       ||= 'http://ens-prod-1.ebi.ac.uk:8000/dbcopy/';
$source_server_url  ||= 'mysql://ensro@mysql-ens-sta-1.ebi.ac.uk:4519/';
$target_server_url  ||= "mysql://ensadmin:$ensadmin_psw\@mysql-ens-vertannot-staging.ebi.ac.uk:4573/";


$source_server_url .= '/' unless $source_server_url =~ /\/$/;
$target_server_url .= '/' unless $target_server_url =~ /\/$/;

Bio::EnsEMBL::Registry->load_registry_from_url($target_server_url);
my %existing_target_species;
foreach my $db_adaptor (@{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')}) {
    #$existing_target_species{ $db_adaptor->species } = 1;
    push @{ $existing_target_species{ $db_adaptor->species } }, $db_adaptor->dbc->dbname;
}


Bio::EnsEMBL::Registry->clear;
Bio::EnsEMBL::Registry->load_registry_from_url($source_server_url);

my @databases_to_copy;
my @db_clash;
my @existing_dbs;
foreach my $db_adaptor (@{Bio::EnsEMBL::Registry->get_all_DBAdaptors(-GROUP => 'core')}) {
    my $dbname = $db_adaptor->dbc->dbname;
    if ($existing_target_species{$db_adaptor->species}) {
        my $all_dbs = $existing_target_species{ $db_adaptor->species };
        my @same_dbs = grep {$_ eq $dbname} @$all_dbs;
        my @diff_dbs = grep {$_ ne $dbname} @$all_dbs;
        if (@same_dbs) {
            push @existing_dbs, $dbname;
        }
        if (@diff_dbs) {
            push @db_clash, [$dbname, \@diff_dbs];
        }
    } elsif ($dbname !~ /ensembl_ancestral/) {
        push @databases_to_copy, $dbname;
    }
}

if (@existing_dbs) {
    warn "These databases already exist on $target_server_url ! Check with the genebuilders that the assembly and geneset it contains are correct.\n";
    warn join("\n", map {"\t$_"} @existing_dbs), "\n";
}


if (@db_clash) {
    warn "These species have databases on $target_server_url with a different name ! The Registry may be confused ! Check with the genebuilders what they are and whether they can be dropped.\n";
    foreach my $a (@db_clash) {
        warn "\t", $a->[0], "\t", join(" ", @{$a->[1]}), "\n";
    }
}

foreach my $dbname (@databases_to_copy) {
    my @cmd = ($db_copy_client, '-a' => 'submit', '-u' => $endpoint_uri, '-s' => "$source_server_url$dbname", '-t' => "$target_server_url$dbname");
    if (system(@cmd)) {
        die "Could not run the command: ", join(" ", @cmd), "\n";
    }
}

