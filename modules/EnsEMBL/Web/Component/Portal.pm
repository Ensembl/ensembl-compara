=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Portal;

use strict;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  
  $self->cacheable(1);
  $self->ajaxable(0);
  
  $self->{'buttons'} = [];
}

sub content {
  my $self = shift;
  my $html;
  
  foreach (@{$self->{'buttons'}}) {
    if ($_->{'url'}) {
      $html .= qq(<a href="$_->{'url'}" title="$_->{'title'}"><img src="/img/$_->{'img'}.gif" class="portal" alt="" /></a>);
    } else {
      $html .= qq|<img src="/img/$_->{'img'}_off.gif" class="portal" alt="" title="$_->{'title'} (NOT AVAILABLE)" />|;
    }
  }
  
  return qq{<div>$html</div>};
}

1;
