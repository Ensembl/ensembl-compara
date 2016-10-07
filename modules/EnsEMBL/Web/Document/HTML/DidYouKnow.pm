=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

use parent qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self  = shift;
  my $hub   = $self->hub;
  my $sd    = $hub->species_defs;
  my $html  = ''; 

  return if $sd->ENSEMBL_SKIP_RSS || ($sd->ENSEMBL_SUBTYPE && $sd->ENSEMBL_SUBTYPE eq 'Archive');

  my $rss_path  = $sd->ENSEMBL_TMP_DIR.'/web/blog/minifeed';
  my $rss_url   = $sd->ENSEMBL_TIPS_RSS;
  my $got       = 0;
  my $tips      = {};

  my %categories = (
                    'new' => 'New!',
                    'did-you-know' => 'Did you know...?', 
                    );

  foreach my $cat (keys %categories) {
    (my $cat_url = $rss_url) =~ s/feed\/$/category\/$cat\/feed\//;
    (my $rss_cat = $cat) =~ s/-/_/g;
    my $cat_path = sprintf('%s/%s/rss.xml', $rss_path, $rss_cat);

    $tips->{$cat} = $self->read_rss_file($hub, $cat_path, $cat_url);
    $got += @{$tips->{$cat}} if $tips->{$cat};
  }

  if ($got) {
    $html .= '<ul class="bxslider">';

    my $limit = 5;
    my @tips_to_show = map {[$categories{'new'}, $_->{'content'}]} @{$tips->{'new'}||[]};

    ## Random did-you-knows
    my $to_add = $limit - scalar(@tips_to_show);

    # On a mirror installation we probably don't have or want an ENSEMBL_TIPS_RSS setting, and
    # so don't want to return an empty 'did-you-know' class html div, so return here.                                            
    return unless (scalar(@tips_to_show) + $to_add);

    ## Add some random did-you-knows
    srand;
    for (my $i = 0; $i < $to_add; $i++) {
      last unless scalar(@{$tips->{'did-you-know'}});
      my $j = int(rand (scalar(@{$tips->{'did-you-know'}}) - 1));
      push @tips_to_show, [$categories{'did-you-know'}, $tips->{'did-you-know'}[$j]{'content'}];
      splice @{$tips->{'did-you-know'}}, $j, 1;
    }

    ## Build HTML list
    foreach (@tips_to_show) {
      $html .= sprintf('<li><div><b>%s</b><br />%s</div></li>', $_->[0], $_->[1]);
    }

    $html .= '</ul>';
  }
  return $html;
}

1;
