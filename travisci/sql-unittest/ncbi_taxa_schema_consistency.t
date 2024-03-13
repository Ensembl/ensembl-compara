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

use strict;
use warnings;

use File::Spec::Functions qw(catfile);
use HTTP::Tiny;
use JSON qw(decode_json);
use Test::More;

use Bio::EnsEMBL::ApiVersion qw(software_version);
use Bio::EnsEMBL::Compara::Utils::Test;

my $compara_branch = Bio::EnsEMBL::Compara::Utils::Test::get_repository_branch();
unless ($compara_branch =~ m|^release/[0-9]+$|) {
    plan skip_all => 'NCBI schema consistency test is only run on Ensembl release branches';
}

my $response = HTTP::Tiny->new->get('https://api.github.com/repos/Ensembl/ensembl-compara');
if ($response->{'success'}) {
    my $content = decode_json($response->{'content'});
    if ($content->{'default_branch'} =~ m|^release/(?<live_version>[0-9]+)$|) {
        if (software_version() <= $+{'live_version'}) {
            plan skip_all => 'NCBI schema consistency test is not run on an Ensembl version after it has been released';
        }
    }
}

## Check that the NCBI Taxonomy tables of the Compara schema are in sync with those of the Ensembl Taxonomy schema

my $multitestdb = Bio::EnsEMBL::Compara::Utils::Test::create_multitestdb();

# Get the Compara schema
my $compara_schema_file = catfile($ENV{'ENSEMBL_ROOT_DIR'}, 'ensembl-compara', 'sql', 'table.sql');
my $compara_db_name = $multitestdb->create_db_name('current_schema');
my $compara_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls($compara_schema_file);
my $compara_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $compara_db_name, $compara_statements,
                                                                     'Can load the Ensembl Compara schema');
my $compara_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($compara_db, $compara_db_name);
Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $compara_db_name);

# Get the Ensembl Taxonomy schema
my $ncbi_taxa_schema_file = catfile($ENV{'ENSEMBL_ROOT_DIR'}, 'ensembl-taxonomy', 'sql', 'table.sql');
my $ncbi_taxa_db_name = $multitestdb->create_db_name('taxonomy_schema');
my $ncbi_taxa_statements = Bio::EnsEMBL::Compara::Utils::Test::read_sqls($ncbi_taxa_schema_file);
my $ncbi_taxa_db = Bio::EnsEMBL::Compara::Utils::Test::load_statements($multitestdb, $ncbi_taxa_db_name, $ncbi_taxa_statements,
                                                                       'Can load the Ensembl Taxonomy schema');
my $ncbi_taxa_schema = Bio::EnsEMBL::Compara::Utils::Test::get_schema_from_database($ncbi_taxa_db, $ncbi_taxa_db_name);
Bio::EnsEMBL::Compara::Utils::Test::drop_database($multitestdb, $ncbi_taxa_db_name);

# Compare the two
my $compara_ncbi_taxa_table_schema;
foreach my $ncbi_taxa_table_name (keys %{$ncbi_taxa_schema}) {
    $compara_ncbi_taxa_table_schema->{$ncbi_taxa_table_name} = $compara_schema->{$ncbi_taxa_table_name};
}

is_deeply($compara_ncbi_taxa_table_schema, $ncbi_taxa_schema,
          'Compara NCBI Taxonomy tables are identical to Ensembl Taxonomy tables');

done_testing();
