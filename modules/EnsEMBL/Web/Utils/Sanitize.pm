=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::Sanitize;

### Methods for sanitising strings, URLs, etc

use base qw(Exporter);

our @EXPORT = our @EXPORT_OK = qw(clean_id strip_HTML);

sub clean_id {
### Convert arbitrary text (e.g. track names) into something programmatically safe
  my ($id, $match) = @_; 
  return unless $id;
  $match ||= '[^\w-]';
  $id =~ s/$match/_/g;
  return $id;
}

sub strip_HTML {
  my $string = shift;
  $string =~ s/<[^>]+>//g;
  return $string;
}

1;
