# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2020] EMBL-European Bioinformatics Institute
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


use File::Spec;
use XML::LibXML;

use Test::Exception;
use Test::More;

use Bio::EnsEMBL::Compara::Utils::Test;

my $xml_parser = XML::LibXML->new(line_numbers => 1);
my $root       = Bio::EnsEMBL::Compara::Utils::Test::get_repository_root();
my $xml_schema = File::Spec->catfile($root, 'scripts', 'pipeline', 'compara_db_config.rng');

ok(-s $xml_schema, "The XML schema exists and is not empty");

my $schema;
lives_ok(
    sub { $schema = XML::LibXML::RelaxNG->new(location => $xml_schema); },
    "$xml_schema is a valid RNG file"
);

sub is_valid_xml {
    my $filename = shift;

    my $xml_document;
    lives_ok(
        sub { $xml_document = $xml_parser->parse_file($filename); },    ## XML::LibXML::Document
        "$filename is a valid XML file"
    );
    if ($xml_document && $filename =~ /\bconf\/.*\/mlss_conf\.xml$/) {
        lives_ok(
            sub { $schema->validate( $xml_document) },
            "$filename follows the RNG specification"
        );
    }
}

my @all_files = Bio::EnsEMBL::Compara::Utils::Test::find_all_files();

foreach my $f (@all_files) {
    if ($f =~ /\.xml$/) {
        is_valid_xml($f);
    }
}

done_testing();

