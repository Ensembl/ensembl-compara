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

package EnsEMBL::Web::Component::UserData::ShareURL;

use strict;

use base qw(EnsEMBL::Web::Component::UserData);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self      = shift;
  my $hub       = $self->hub;
  my @shares    = grep $_, $hub->param('share_id');
  my $share_ref = join ';', map "share_ref=$_", @shares;
  my $reload    = $hub->param('reload') ? '<div class="modal_reload"></div>' : '';
  my $url       = $hub->referer->{'absolute_url'};
     $url      .= $url =~ /\?/ ? ';' : '?' unless $url =~ /;$/;
     $url      .= $share_ref;
     
  return qq{
    <p class="space-below">To share this data, use the URL:</p>
    <p class="space-below">$url</p>
    $reload
  };
}

1;
