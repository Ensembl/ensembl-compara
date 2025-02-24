#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

init_dump_registry.pl

=head1 DESCRIPTION

Initialises a static registry for the Compara FTP dumps of the given division and release.

=head1 EXAMPLES

    $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/pipeline/init_dump_registry.pl \
        --division pan --release 112 --outfile dump_reg_conf.pm

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--division STR]>

Ensembl division.

=item B<[--release INT]>

Ensembl release.

=item B<[--outfile PATH]>

Path of output dump registry file.

=item B<[--compara_db ALIAS]>

(Optional) Compara database alias (default: 'compara_curr').

=item B<[--ancestral_db ALIAS]>

(Optional) Compara ancestral database alias (default: 'ancestral_curr').

=item B<[--compara_dump_host HOSTNAME]>

(Optional) Server hosting the Compara database to be dumped.

=item B<[--ancestral_dump_host HOSTNAME]>

(Optional) Server hosting the Compara ancestral database to be dumped.

=item B<[--core_dump_hosts HOSTNAME]>

(Optional) Comma-delimited list of servers hosting the core databases to be used in Compara FTP dumps.

=back

=cut

use strict;
use warnings;

use File::Basename qw(dirname);
use File::Spec::Functions qw(catdir catfile rel2abs splitdir splitpath);
use Getopt::Long;
use JSON qw(decode_json);
use Pod::Usage;
use List::Util qw(max);

use Bio::EnsEMBL::ApiVersion qw(software_version);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::IO qw(slurp spurt);
use Bio::EnsEMBL::Compara::Utils::Registry;
use Bio::EnsEMBL::Compara::Utils::RunCommand;
use Bio::EnsEMBL::Compara::Utils::Test;


sub get_adaptor_init_text {
    my ($dba_class, $adaptor_params) = @_;
    my @adaptor_param_names = sort keys %{$adaptor_params};
    my ($max_param_name_length) = max(map {length($_)} @adaptor_param_names);

    my $text = "${dba_class}->new(\n";
    foreach my $param_name (@adaptor_param_names) {
        my $param_value = $adaptor_params->{$param_name};
        my $output_name = sprintf("%-${max_param_name_length}s", $param_name);
        my $output_value = $param_value =~ /^[0-9]+$/ ? $param_value : "'$param_value'";
        $text .= "    -${output_name} => $output_value,\n",
    }
    $text .= ");\n\n";

    return $text;
}

sub get_host_name {
    my ($host_name_or_alias) = @_;
    my $cmd_args = [$host_name_or_alias, 'host'];
    my $cmd_opts = { die_on_failure => 1 };
    my $run_cmd = Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd_args, $cmd_opts);
    my $host_full_name = $run_cmd->out;
    chomp $host_full_name;
    return $host_full_name
}

sub get_repo_root {
    my ($volume, $script_dir_path, $script_file_name) = splitpath(rel2abs(__FILE__));
    my @path_parts = splitdir($script_dir_path);
    pop @path_parts until $path_parts[$#path_parts] eq 'ensembl-compara' || scalar(@path_parts) == 0;
    throw("script $script_file_name is not in the ensembl-compara repo") if (scalar(@path_parts) == 0);
    return catdir(@path_parts);
}


my ( $division, $release, $outfile );
my ( $help, $compara_dump_host, $ancestral_dump_host, $core_dump_hosts );
my $compara_db_alias = 'compara_curr';
my $ancestral_db_alias = 'ancestral_curr';
GetOptions(
    'help|?'                => \$help,
    'division=s'            => \$division,
    'release=i'             => \$release,
    'outfile=s'             => \$outfile,
    'compara_db=s'          => \$compara_db_alias,
    'ancestral_db=s'        => \$ancestral_db_alias,
    'compara_dump_host=s'   => \$compara_dump_host,
    'ancestral_dump_host=s' => \$ancestral_dump_host,
    'core_dump_hosts=s'     => \$core_dump_hosts,
) or pod2usage(-verbose => 2);

# Handle "print usage" scenarios
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$division or !$release or !$outfile;


my $eg_release = $release - 53;

my %div_to_compara_db_name = (
    'vertebrates' => "ensembl_compara_${release}",
    'fungi' => "ensembl_compara_fungi_${eg_release}_${release}",
    'metazoa' => "ensembl_compara_metazoa_${eg_release}_${release}",
    'pan' => "ensembl_compara_pan_homology_${eg_release}_${release}",
    'plants' => "ensembl_compara_plants_${eg_release}_${release}",
    'protists' => "ensembl_compara_protists_${eg_release}_${release}",
);

my %div_to_ancestral_db_name = (
    'vertebrates' => "ensembl_ancestral_${release}",
    'plants' => "ensembl_ancestral_plants_${eg_release}_${release}",
);

my $repo_root_dir = get_repo_root();
my $config_dir = catdir($repo_root_dir, 'conf', $division);

my $dump_host_file = catfile($config_dir, 'dump_hosts.json');
my $dump_hosts_by_parity = decode_json(slurp($dump_host_file));

my $allowed_species_file = catfile($config_dir, 'allowed_species.json');
my $allowed_species = -e $allowed_species_file ? decode_json(slurp($allowed_species_file)): [];

my $additional_species_file = catfile($config_dir, 'additional_species.json');
my $additional_species = -e $additional_species_file ? decode_json(slurp($additional_species_file)) : {};

my $software_version = software_version();
if ($software_version != $release) {
    throw("Ensembl software version ($software_version) does not match Ensembl release ($release)");
}

my $compara_branch = Bio::EnsEMBL::Compara::Utils::Test::get_repository_branch();
my $branch_version;
if ($compara_branch =~ m|^release/(?<ensembl_version>[0-9]+)$|) {
    $branch_version = $+{ensembl_version};
} else {
    throw("failed to extract Ensembl version from Compara branch '$compara_branch'");
}

if ($branch_version != $release) {
    throw("Compara branch version ($branch_version) does not match Ensembl release ($release)");
}

my $parity = $release % 2 == 0 ? 'even' : 'odd';
my %dump_host_map = %{$dump_hosts_by_parity->{$parity}};

if (defined $compara_dump_host) {
    $dump_host_map{'compara_dump_host'} = get_host_name($compara_dump_host);
}

if (defined $ancestral_dump_host) {
    $dump_host_map{'ancestral_dump_host'} = get_host_name($ancestral_dump_host);
}

if (defined $core_dump_hosts) {
    my %core_host_set = map { get_host_name($_) => 1 } split(/,/, $core_dump_hosts);
    $dump_host_map{'core_dump_hosts'} = [keys %core_host_set];
}

my %exp_sp_info;
foreach my $species_name (@{$allowed_species}) {
    $exp_sp_info{$division}{$species_name} = 1;
}
while (my ($division, $species_names) = each %{$additional_species}) {
    foreach my $species_name (@{$species_names}) {
        $exp_sp_info{$division}{$species_name} = 1;
    }
}


my $core_db_pattern = qr/^[a-z0-9_]+?(?<collection_core_tag>_collection)?_core(?:_\d+)?_\d+_\w+$/;

my %cores_by_species_name;
my %core_adaptor_param_sets;
foreach my $core_host (@{$dump_host_map{'core_dump_hosts'}}) {
    my $core_port = Bio::EnsEMBL::Compara::Utils::Registry::get_port($core_host);

    my $cmd_args = [$core_host, '-Ne', 'SHOW DATABASES'];
    my $cmd_opts = { die_on_failure => 1 };
    my $run_cmd = Bio::EnsEMBL::Compara::Utils::RunCommand->new_and_exec($cmd_args, $cmd_opts);

    my @core_db_names;
    my %core_has_collection_tag;
    foreach my $db_name (split(/\n/, $run_cmd->out)) {
        if ($db_name =~ /$core_db_pattern/) {
            $core_has_collection_tag{$db_name} = defined $+{'collection_core_tag'} ? 1 : 0;
            push(@core_db_names, $db_name);
        }
    }

    my $core_host_dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
        -host   => $core_host,
        -port   => $core_port,
        -user   => 'ensro',
    );

    foreach my $core_db_name (@core_db_names) {

        my $core_version_query = qq/
            SELECT meta_value
            FROM ${core_db_name}.meta
            WHERE meta_key = 'schema_version'
        /;

        my $core_species_meta_query = qq/
            SELECT species_id, meta_key, meta_value
            FROM ${core_db_name}.meta
            WHERE meta_key IN ('species.division', 'species.production_name')
        /;

        my $core_version = $core_host_dbc->sql_helper->execute_single_result(-SQL => $core_version_query);
        my $results = $core_host_dbc->sql_helper->execute(-SQL => $core_species_meta_query);

        my %meta_by_species_id;
        foreach my $result (@{$results}) {
            my ($species_id, $meta_key, $meta_value) = @{$result};
            $meta_by_species_id{$species_id}{$meta_key} = $meta_value;
        }

        my $multispecies_db = $core_has_collection_tag{$core_db_name} || max(keys %meta_by_species_id) > 1 ? 1 : 0;

        my $core_db_key = sprintf("%s:%d/%s", $core_host, $core_port, $core_db_name);
        while (my ($species_id, $species_meta) = each %meta_by_species_id) {
            my $species_name = $species_meta->{'species.production_name'};
            my $species_division = $species_meta->{'species.division'};
            if ($species_division =~ /^Ensembl([A-Za-z]+)$/) {
                $species_division = lc $1;
            } else {
                throw("species $species_name has unknown division '$species_division'");
            }

            if ($core_version == $release && exists $exp_sp_info{$species_division}{$species_name}) {
                if (exists $core_adaptor_param_sets{$species_name}) {
                    my $existing = $core_adaptor_param_sets{$species_name};
                    throw(sprintf("specified core hosts have multiple databases for species %s: %s vs %s:%d/%s", $species_name,
                                  $core_db_key, $existing->{'host'}, $existing->{'port'}, $existing->{'dbname'}));
                }

                $core_adaptor_param_sets{$species_name} = {
                    'dbname'          => $core_db_name,
                    'group'           => 'core',
                    'host'            => $core_host,
                    'multispecies_db' => $multispecies_db,
                    'pass'            => '',
                    'port'            => $core_port,
                    'species'         => $species_name,
                    'species_id'      => $species_id,
                    'user'            => 'ensro',
                };
            }

            push(@{$cores_by_species_name{$species_name}}, $core_db_key);
        }
    }

    $core_host_dbc->disconnect_if_idle;
}

while (my ($division, $species_name_set) = each %exp_sp_info) {
    foreach my $species_name (sort keys %{$species_name_set}) {
        if (!exists $core_adaptor_param_sets{$species_name}) {
            my $msg = "no release-$release $division core database found for $species_name";
            if (exists $cores_by_species_name{$species_name}) {
                $msg .= ", though the following core database(s) may be a close match: " . join(", ", @{$cores_by_species_name{$species_name}});
            }
            throw($msg);
        }
    }
}


my $version_query = q/
    SELECT meta_value
    FROM meta
    WHERE meta_key = 'schema_version'
/;

my $compara_db_name = $div_to_compara_db_name{$division};
my $compara_host = $dump_host_map{'compara_dump_host'};
my $compara_port = Bio::EnsEMBL::Compara::Utils::Registry::get_port($compara_host);

my $compara_dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
    -dbname => $compara_db_name,
    -host   => $compara_host,
    -port   => $compara_port,
    -user   => 'ensro',
);

my $compara_version = $compara_dbc->sql_helper->execute_single_result(-SQL => $version_query);
if ($compara_version != $release) {
    throw("Compara database schema version ($compara_version) does not match Ensembl release ($release)");
}

my $compara_adaptor_params = {
    'dbname'  => $compara_db_name,
    'group'   => 'compara',
    'host'    => $compara_host,
    'pass'    => '',
    'port'    => $compara_port,
    'species' => $compara_db_alias,
    'user'    => 'ensro',
};

my $ancestral_adaptor_params;
if (exists $dump_host_map{'ancestral_dump_host'}) {
    my $ancestral_db_name = $div_to_ancestral_db_name{$division};
    my $ancestral_host = $dump_host_map{'ancestral_dump_host'};
    my $ancestral_port = Bio::EnsEMBL::Compara::Utils::Registry::get_port($ancestral_host);

    if (!defined $ancestral_db_name) {
        throw("ancestral database not expected for division $division");
    }

    my $ancestral_dbc = Bio::EnsEMBL::DBSQL::DBConnection->new(
        -dbname => $ancestral_db_name,
        -host   => $ancestral_host,
        -port   => $ancestral_port,
        -user   => 'ensro',
    );

    my $ancestral_version = $ancestral_dbc->sql_helper->execute_single_result(-SQL => $version_query);
    if ($ancestral_version != $release) {
        throw("Compara ancestral database schema version ($ancestral_version) does not match Ensembl release ($release)");
    }

    $ancestral_adaptor_params = {
        'dbname'  => $ancestral_db_name,
        'group'   => 'core',
        'host'    => $ancestral_host,
        'pass'    => '',
        'port'    => $ancestral_port,
        'species' => $ancestral_db_alias,
        'user'    => 'ensro',
    };
}

my $registry_text = "\n\n" . join("\n", ('use Bio::EnsEMBL::DBSQL::DBAdaptor;', 'use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;')) . "\n\n";

$registry_text .= get_adaptor_init_text('Bio::EnsEMBL::Compara::DBSQL::DBAdaptor', $compara_adaptor_params);

if (defined $ancestral_adaptor_params) {
    $registry_text .= get_adaptor_init_text('Bio::EnsEMBL::DBSQL::DBAdaptor', $ancestral_adaptor_params);
}

foreach my $species_name (sort keys %core_adaptor_param_sets) {
    my $core_adaptor_param_set = $core_adaptor_param_sets{$species_name};
    $registry_text .= get_adaptor_init_text('Bio::EnsEMBL::DBSQL::DBAdaptor', $core_adaptor_param_set);
}

$registry_text .= "1;\n";

spurt($outfile, $registry_text);
