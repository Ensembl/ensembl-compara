=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions

=head1 DESCRIPTION

This Runnable checks that the version of the Compara schema matches the version
of the Core API.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AssertMatchingVersions;

use strict;
use warnings;

use Bio::EnsEMBL::ApiVersion ();

use base ('Bio::EnsEMBL::Hive::RunnableDB::SqlHealthcheck');


sub param_defaults {
    return {
        'manual_ok'     => 0,   # to override the test
        'core_version'  => Bio::EnsEMBL::ApiVersion::software_version(),
        'description'   => 'The version of the Compara schema must match the Core API (#core_version#). Set "manual_ok" to 1 to override the test.',
        'query'         => 'SELECT * FROM meta WHERE meta_key = "schema_version" AND meta_value != #core_version# AND NOT #manual_ok#',
    }
}

1;

