#! /usr/bin/perl 
# Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

use EnsEMBL::Web::Tools::Document;

my $export = shift @ARGV;
my $base = shift @ARGV;
my $support = shift @ARGV;
my @locations = @ARGV;

if (-e $export) {
print "Exporting to $export\n";
print "Searching for documentation\n";
my $document = EnsEMBL::Web::Tools::Document->new( (
                 directory => \@locations,
                 identifier => "###"
               ) );

$document->find_modules;
$document->generate_html($export, $base, $support);
print "Done\n";
}
