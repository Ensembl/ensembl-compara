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

package EnsEMBL::Web::Document::Element::Stylesheet;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Document::Element);

use EnsEMBL::Web::Utils::FileHandler qw(file_get_contents);

sub init {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my @css_groups    = @{$species_defs->get_config('ENSEMBL_JSCSS_FILES')->{'css'}||[]};

  push @css_groups,@{$species_defs->get_config('ENSEMBL_JSCSS_FILES')->{'image'}||[]};
  for (@css_groups) {
    next unless $_->condition($hub);

    if((($hub->param('debug') || '') eq 'css' || $species_defs->ENSEMBL_DEBUG_CSS) and @{$_->files}) {
      $self->add_sheet(sprintf '/CSS?%s', $_->url_path) for @{$_->files};
    } else {
      $self->add_sheet($_->minified_url_path);
    }
  }
}

sub content {
  my $self = shift;

  my @all;
  foreach my $s (@{$self->{'_sheets'}||[]}) {
    my $base = '';
    $base = $self->static_server if $s =~ /^\//;
    my $url = "$base$s";
    my $ieu = $url;
    $ieu =~ s/\.css$/.ie7.css/;
    my $link = qq(<link rel="stylesheet" type="text/css" media="all");
    push @all,qq(<!--[if lte IE 7]>$link href="$ieu"/><![endif]-->);
    push @all,qq(<!--[if gt IE 7]>$link href="$url"/><![endif]-->);
    push @all,qq(<!--[if !IE]><!-->$link href="$url"/><!--<![endif]-->);
  }
  return join('',@all);

}

sub add_sheet {
  my ($self, $sheet) = @_;
  return unless $sheet;
  push @{$self->{'_sheets'}}, $sheet unless grep { $sheet eq $_ } @{$self->{'_sheets'}};
}

1;
