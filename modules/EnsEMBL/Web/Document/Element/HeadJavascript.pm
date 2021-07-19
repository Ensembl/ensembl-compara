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

package EnsEMBL::Web::Document::Element::HeadJavascript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Document::Element);

sub init {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $js_groups     = $species_defs->get_config('ENSEMBL_JSCSS_FILES')->{'js'};

  for (@$js_groups) {
    next unless $_->condition($hub);

    if (($hub->param('debug') || '') eq 'js' || $species_defs->ENSEMBL_DEBUG_JS) {
      $self->add_script($_->url_path) for @{$_->files};
    } else {
      $self->add_script($_->minified_url_path);
    }
  }
}

sub content {
  my $self = shift;

  $self->shared->{'sent_js'} = 1;
  return join '',
    map(sprintf(qq(<script defer type="text/javascript" src="%s%s"></script>\n), $self->static_server, $_), @{$self->{'_sources'} || []}),
    map(sprintf(qq(<script type="text/javascript">%s</script>), $_), @{$self->{'_inline'} || []});
}

sub add_script {
  my ($self, $src) = @_;

  push @{$self->{'_sources'}}, $src unless grep { $src eq $_ } @{$self->{'_sources'}};
}

1;
