# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2022] EMBL-European Bioinformatics Institute
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

use lib ('..');
use XHTML::Validator;

my $strings = {};

$strings->{'no-tags'} = {
  'This is a test &amp; it works'    => undef,
  "This ia a test & it doesn't work" => 'entity issue',
  "This is a test &fred; it doesn't work" => 'unknown ent',
};

$strings->{'in-line'} = {
  '<p>This is a paragraph</p>' => 'No paragraphs',
  'This is text with a <a href="test">Link</a>' => undef
};

$strings->{'normal'} = {
 %{$strings->{'no-tags'}},
 '<a href="test">aa</a></strong>'          => 'Too many closes',
 '<strong><a href="test">aa</a>'           => 'Insufficient closes',
 '<li>TEST</li>'                           => 'Not rootable',
 '<strong><em>test</strong></em>'          => 'tag order mismatch',
 '<a href="this_is_a_test.html">xx</a>'    => undef,
 '<a href="this_is_a_test.html>xx</a>'     => 'Missing " in attribute',
 '<a href=this_is_a_test.html>xx</a>'      => 'No "s in attributes',
 '<a href="this_is_&amp;a_test.html" >xx</a>' => undef,
 '<a href="this_is_&ampa_test.html" >xx</a>'  => 'No ; for entity',
 '<a href="this_is_&a_test;.html" >xx</a>'    => 'Unrecognised entity',
 '<a  bob="this_is_&amp;.html">xx</a>'      => 'Unrecognised attr',
 '<aa>a</aa>'                              => 'unrecognised tag',
 '<ul>
  <li><a href="test.html">This is a test</a></li>
  <li><strong><a href="test2.html"><em>A</em></a></strong></li>
</ul>' => undef,
};

$strings->{'no-tags'}{'this is <a href="with_a_tag">test with a tag</a>'} = 'has a tag';

foreach my $k ( sort keys %$strings ) {
  my $x = new XHTML::Validator($k);
  print "
========================================================================
VALIDATOR: $k";
  foreach my $string ( sort keys %{$strings->{$k}} ) {
    my $value  = $strings->{$k}{$string};
    my $result = $x->validate( $string );
    print "
========================================================================
$string
------------------------------------------------------------------------";
    print $result && $value ? "\n  OK  - $result\n  OK  - $value" 
        : $result || $value ? "\n  ERR - $result\n  ERR - $value"
	:                     "\n  OK  - VALID"
	;
  }
  print "
========================================================================
";
}

1;
