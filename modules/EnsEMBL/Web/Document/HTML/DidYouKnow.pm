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
  my $tips = $MEMD && $MEMD->get('::TIPS') || {};
  
  my %categories = (
                    'new' => 'New!',
                    'did-you-know' => 'Did you know...?', 
                    );

  ## Check the cache, then fetch new tips
  foreach my $cat (keys %categories) {
    (my $cat_url = $rss_url) =~ s/feed\/$/category\/$cat\/feed\//;
    unless (scalar(@{$tips->{$cat}||[]}) && $cat_url) {
      $tips->{$cat} = $self->get_rss_feed($hub, $cat_url);

      if (scalar(@{$tips->{$cat}||[]})) {
        $_->{'content'} = encode_utf8($_->{'content'}) for @{$tips->{$cat}};
      }
    }
    $MEMD->set('::TIPS', $tips, 3600, qw(STATIC TIPS)) if $MEMD;
  }

  $html .= '<div class="did-you-know"><ul class="bxslider">';

  ## We want all the news plus some random tips
  my $limit = 5;

  my @tips_to_show = map {[$categories{'new'}, $_->{'content'}]} @{$tips->{'new'}};

  ## Random did-you-knows
  my $to_add = $limit - scalar(@tips_to_show);
  srand;

  for (my $i = 0; $i < $to_add; $i++) {
    my $j = int(rand (scalar(@{$tips->{'did-you-know'}}) - 1));
    push @tips_to_show, [$categories{'did-you-know'}, $tips->{'did-you-know'}[$j]{'content'}];
    splice @{$tips->{'did-you-know'}}, $j, 1;
  }

  ## Build HTML list
  foreach (@tips_to_show) {
    $html .= sprintf('<li><div><b>%s</b><br />%s</div></li>', $_->[0], $_->[1]);
  }

  $html .= '</ul></div>';

  return $html;
}

1;
