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

package EnsEMBL::Web::Controller::CSS;

use strict;
use warnings;

use List::Util qw(first);

use parent qw(EnsEMBL::Web::Controller);

sub process {
  my $self          = shift;
  my $r             = $self->r;
  my $species_defs  = $self->species_defs;
  my $filename      = $self->query;
  my $file          = $filename ? first { $filename eq $_->url_path } map { @{$_->files} } @{$species_defs->ENSEMBL_JSCSS_FILES->{'css'} || []} : undef;
  my $content       = $filename ? $file ? $file->get_contents($species_defs, 'css') : "/* ERROR: file $filename is not present in the document root */\n" : "/* ERROR: No file name provided */\n";

  # don't pollute logs with CSS requests
  $r->subprocess_env('LOG_REQUEST_IGNORE', 1);

  # set correct headers
  $r->content_type('text/css');
  $r->headers_out->set('Content-Length', length $content);

  $r->print($content);
}

1;
