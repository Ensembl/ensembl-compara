#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2019] EMBL-European Bioinformatics Institute
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
use Bio::EnsEMBL::Utils::ConfigRegistry;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Taxonomy::DBSQL::TaxonomyDBAdaptor;

my $curr_release = 98;

# ---------------------- CURRENT CORE DATABASE ---------------------------------

# The majority of core databases live on staging servers:
# Bio::EnsEMBL::Registry->load_registry_from_url(
#     "mysql://ensro\@mysql-ens-sta-1.ebi.ac.uk:4519/$curr_release");
Bio::EnsEMBL::Registry->load_registry_from_url(
    "mysql://ensro\@mysql-ens-vertannot-staging:4573/$curr_release");
# Wheat (tiritcum aestivum) is located in a different server between releases:
# Bio::EnsEMBL::DBSQL::DBAdaptor->new(
#     -host    => 'mysql-ens-sta-3',
#     -user    => 'ensro',
#     -pass    => '',
#     -port    => 4160,
#     -species => 'triticum_aestivum',
#     -dbname  => 'triticum_aestivum_core_45_98_4',
# );

# ---------------------- COMPARA DATABASE LOCATION -----------------------------

Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(
    -host    => 'mysql-ens-compara-prod-7',
    -user    => 'ensadmin',
    -pass    => $ENV{'ENSADMIN_PSW'},
    -port    => 4617,
    -species => 'compara_master',
    -dbname  => 'jalvarez_master_citest',
);

1;
