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

package EnsEMBL::Web::Document::HTML::DidYouKnow;

### This module outputs a list of tips plus a random item from the Wordpress "minifeed" RSS feed 

use strict;
use warnings;

use LWP::UserAgent;
use Encode qw(encode_utf8);

use EnsEMBL::Web::Hub;
use EnsEMBL::Web::Cache;

use base qw(EnsEMBL::Web::Document::HTML);

our $MEMD = EnsEMBL::Web::Cache->new(
  enable_compress    => 1,
  compress_threshold => 10_000,
);

sub render {
  my $self           = shift;
  my $hub            = EnsEMBL::Web::Hub->new;
  my $sd             = $hub->species_defs;
  my $static_server  = $sd->ENSEMBL_STATIC_SERVER;
  my $img_url        = $sd->img_url;
  my $sitename       = $sd->ENSEMBL_SITETYPE;
  my $html           = ''; 

  my $rss_url = $sd->ENSEMBL_TIPS_RSS;
  my $tips = []; #$MEMD && $MEMD->get('::TIPS') || [];
  
  ## Check the cache, then fetch new tips
  unless (@$tips && $rss_url) {
    $tips = $self->get_rss_feed($hub, $rss_url);

    if ($tips && @$tips) {
      $_->{'content'} = encode_utf8($_->{'content'}) for @$tips;
      $MEMD->set('::TIPS', $tips, 3600, qw(STATIC TIPS)) if $MEMD;
    }
  }

  $html .= '<div class="info-box did-you-know"><ul class="bxslider">';

  foreach (@$tips) {
    $html .= sprintf('<li><div><b>Did you know...?</b><br />%s</div></li>', $_->{'content'});
  }

  $html .= '</ul></div>';

  return $html;
}

1;
