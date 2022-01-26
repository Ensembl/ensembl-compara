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

package EnsEMBL::Web::Component::Help::ArchiveRedirect;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Component::Help::ArchiveList);

sub top_message {
  return q(The Ensembl Archive you tried to reach is not available. You can go to one of the other available archives:);
}

sub content {
  my $self      = shift;
  my $content   = $self->SUPER::content(@_);
  my $url_path  = ($self->hub->param('src') || '') =~ s/^.+?\.[^\/]+//r; # remove the hostname

  return $content =~ s/href\=\"([^\"]+\.[^\/\"]+)[^\"]*\"/href="$1$url_path"/gr; # replace url paths for all the links in the page
}

1;
