=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::File::Utils::URL;

### Non-OO library for common functions required for handling remote files 

use strict;

use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(file_exists read_file);
our %EXPORT_TAGS = (all     => [@EXPORT_OK]);

sub file_exists {
### Check if a file of this name exists
### @param url - URL of file
### @return Boolean
  my $url = shift;
}

sub read_file {
### Get entire content of file
### @param url - URL of file
### @param Args (optional) Hashref 
###         compression String - compression type
###         no_exception Boolean - whether to throw an exception
### @return String (entire file)
  my ($url, $args) = @_;
  my $content;

  my $compression = defined($args->{'compression'}) || _compression($url);

  if ($@ && !$args->{'no_exception'}) {
    throw exception('UrlException', sprintf qq(Could not read file '%s' due to following errors: \n%s), $url, $@);
  }
  return $content;
}

1;

