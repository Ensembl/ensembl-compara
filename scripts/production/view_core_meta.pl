#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

=head1 NAME

view_core_meta.pl

=head1 DESCRIPTION

This script fetches core metadata and writes it to a TSV file.

=head1 SYNOPSIS

     ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/view_core_meta.pl \
    --registry_url mysql://ensro@mysql-ens-vertannot-staging:4573/116 --outfile metadata.tsv

    $ENSEMBL_ROOT_DIR/ensembl-compara/scripts/production/view_core_meta.pl \
    --registry_file ${COMPARA_REG_PATH} --compara_division ${COMPARA_DIV} --outfile "${COMPARA_DIV}.tsv"

    ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/view_core_meta.pl \
    --registry_url mysql://ensro@mysql-ens-sta-1:4519/116 --ensembl_division EnsemblVertebrates --outfile EnsemblVertebrates.tsv

    ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/view_core_meta.pl \
    --registry_url mysql://ensro@mysql-ens-sta-3:4160/116 --ensembl_division EnsemblPlants --outfile EnsemblPlants.tsv

    ${ENSEMBL_ROOT_DIR}/ensembl-compara/scripts/production/view_core_meta.pl \
    --registry_url mysql://ensro@mysql-ens-sta-4:4494/116 --ensembl_division EnsemblBacteria --outfile EnsemblBacteria.tsv

=head1 OPTIONS

=over

=item B<[--help]>

Prints help message and exits.

=item B<[--registry_file PATH]>

Ensembl registry file. Mutually exclusive with '--registry_url'.

=item B<[--registry_url PATH]>

Ensembl registry URL. Mutually exclusive with '--registry_file'.

=item B<[-o|--outfile PATH]>

Output metadata file.

=item B<[--preset STR]>

(Optional) Preset meta key list name (default: 'compara').

=item B<[--ensembl_division STR]>

(Optional) Fetch metadata for cores in this division (e.g. 'EnsemblFungi'). Mutually exclusive with '--compara_division'.

=item B<[--compara_division STR]>

(Optional) Fetch metadata for cores in this Compara division (e.g. 'fungi'). Mutually exclusive with '--ensembl_division'.

=back

=cut


use strict;
use warnings;

use File::Basename qw(fileparse);
use File::Copy qw(move);
use File::Spec::Functions qw(catfile);
use File::Temp qw(tempdir);
use Getopt::Long;
use JSON qw(decode_json encode_json);
use Pod::Usage;
use Text::CSV;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::IO qw(slurp);
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::Test qw(get_repository_root);


my @compara_divisions = (
    'fungi',
    'metazoa',
    'pan',
    'plants',
    'protists',
    'vertebrates',
);

my @ensembl_divisions = (
    'EnsemblBacteria',
    'EnsemblFungi',
    'EnsemblMetazoa',
    'EnsemblPlants',
    'EnsemblProtists',
    'EnsemblVertebrates',
);

our %META_KEY_PRESETS = (
    'compara' => [
        'species.production_name',
        'species.display_name',
        'species.division',
        'schema_version',
        'species.taxonomy_id',
        'species.species_taxonomy_id',
        'assembly.default',
        'genebuild.start_date',
        'genebuild.last_geneset_update',
        'strain.type',
        'species.strain',
        'species.strain_group',
    ],
);


my $help;
my $registry_file;
my $registry_url;
my $outfile;
my $preset = 'compara';
my $ensembl_division;
my $compara_division;
my $verbose = 0;

GetOptions(
    'help|?' => \$help,
    'registry_file=s' => \$registry_file,
    'registry_url=s' => \$registry_url,
    'o|outfile=s' => \$outfile,
    'preset=s' => \$preset,
    'ensembl_division=s' => \$ensembl_division,
    'compara_division=s' => \$compara_division,
);
pod2usage(-exitvalue => 0, -verbose => 1) if $help;
pod2usage(-verbose => 1) if !$outfile;


my $registry = 'Bio::EnsEMBL::Registry';
if ($registry_file && $registry_url) {
    throw("only one of parameters '--registry_file' or '--registry_url' can be specified");
} elsif ($registry_file) {
    $registry->load_all($registry_file, 0, 0, 0, 'throw_if_missing');
} elsif ($registry_url) {
    $registry->load_registry_from_url($registry_url);
} else {
    throw("one of parameters '--registry_file' or '--registry_url' must be specified");
}

my %compara_prod_name_set;
if ($compara_division && $ensembl_division) {
    throw("only one of parameters '--ensembl_division' or '--compara_division' can be defined");
} elsif ($compara_division) {
    if (!grep {$_ eq $compara_division} @compara_divisions) {
        throw("unknown compara division: '$compara_division'");
    }

    my $repo_root = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
    my $config_dir = catfile($repo_root, 'conf', $compara_division);

    my $allowed_species_file = catfile($config_dir, 'allowed_species.json');
    if (-e $allowed_species_file) {
        my $allowed_species = decode_json(slurp($allowed_species_file));
        foreach my $prod_name (@{$allowed_species}) {
            $compara_prod_name_set{$prod_name} = 1;
        }
    }

    my $additional_species_file = catfile($config_dir, 'additional_species.json');
    if (-e $additional_species_file) {
        my $additional_species = decode_json(slurp($additional_species_file));
        foreach my $div_prod_names (values %{$additional_species}) {
            foreach my $prod_name (@{$div_prod_names}) {
                $compara_prod_name_set{$prod_name} = 1;
            }
        }
    }

} elsif ($ensembl_division) {
    if (!grep {$_ eq $ensembl_division} @ensembl_divisions) {
        throw("unknown Ensembl division: '$ensembl_division'");
    }
}


Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor->pool_all_DBConnections();

my @registry_names = sort @{$registry->get_all_species()};

my ($output_file_name, $output_dir) = fileparse($outfile);
my $temp_dir = tempdir( CLEANUP => 1, DIR => $output_dir );
my $temp_meta_file_path = catfile($temp_dir, $output_file_name);

my $csv = Text::CSV->new ({ escape_char => "\\", quote_char => "'", sep_char => "\t", undef_str => '<NA>' });
open my $fh, '>', $temp_meta_file_path or throw("Failed to open [$temp_meta_file_path]: $!");
my @rel_meta_keys = @{$META_KEY_PRESETS{$preset}};
my @out_col_names = ('host', 'dbname', @rel_meta_keys);
$csv->say($fh, \@out_col_names);

foreach my $registry_name (@registry_names) {
    next if $registry_name =~ /ancestral sequences/i;

    my $core_dba = $registry->get_DBAdaptor($registry_name, 'core');
    my $meta_container = $core_dba->get_MetaContainer();

    my $prod_name = $meta_container->get_production_name();
    next if $prod_name eq 'ancestral_sequences';

    if ($compara_division) {
        if (%compara_prod_name_set && ! exists($compara_prod_name_set{$prod_name})) {
            next;
        }
    } elsif ($ensembl_division) {
        my $division = $meta_container->get_division();
        if ($division && $division ne $ensembl_division) {
            next;
        }
    }

    my @row = ($core_dba->dbc->host, $core_dba->dbc->dbname);
    foreach my $meta_key (@rel_meta_keys) {
        my $field;
        my @meta_values = @{$meta_container->list_value_by_key($meta_key)};
        if (scalar(@meta_values) == 1) {
            $field = $meta_values[0];

            # If a field contains a tab or newline character, we dump
            # the field as a JSON scalar. Any tabs or newlines should
            # become '\t' or '\n' (respectively) in the output field.
            if ($field =~ /[\t\n]/) {
                $field = encode_json($field);
            }

        } elsif (scalar(@meta_values) > 1) {
            $field = encode_json(\@meta_values);
        }
        push(@row, $field);
    }
    $csv->say($fh, \@row);
}

close $fh or throw("Failed to close [$temp_meta_file_path]: $!");

move($temp_meta_file_path, $outfile);
