=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::IOWrapper::Indexed;

### Parent for large indexed formats that are attached from a remote URL

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::IO::Utils;
use Bio::EnsEMBL::IO::Parser;
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_use);
use EnsEMBL::Web::Utils::FormatText qw(date_format);
use File::Path qw(make_path);

use parent qw(EnsEMBL::Web::IOWrapper);

sub open {
  ## Factory method - creates a wrapper of the appropriate type
  ## based on the format of the file given
  my ($url, $format, $args) = @_;

  my %format_to_class = Bio::EnsEMBL::IO::Utils::format_to_class;
  my $subclass = $format_to_class{lc $format};
  return undef unless $subclass;
  my $class = 'EnsEMBL::Web::IOWrapper::'.$subclass;

  my $wrapper;
  if (dynamic_use($class, 1)) {
    my $parser = Bio::EnsEMBL::IO::Parser::open_as($format, $url);

    if ($parser) {

      $wrapper = $class->new({
                              'parser' => $parser, 
                              'format' => $format,
                              %{$args->{options}||{}}
                            });
    }  
  }
  return $wrapper;
}

sub nearest_feature { return undef; }

1;
