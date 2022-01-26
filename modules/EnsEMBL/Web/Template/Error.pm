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

package EnsEMBL::Web::Template::Error;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::SpeciesDefs;

use parent qw(EnsEMBL::Web::Template);

sub new {
  my $self = shift->SUPER::new(@_);

  $self->{'species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new;
  $self->{'title'}        ||= $self->{'heading'};
  $self->{'css'}            = ([ grep $_->{'group_name'} eq 'components', @{$self->{'species_defs'}->ENSEMBL_JSCSS_FILES->{'css'}} ]->[0]->minified_url_path) =~ s/^\///r;
  $self->{'js'}             = ([ grep $_->{'group_name'} eq 'components', @{$self->{'species_defs'}->ENSEMBL_JSCSS_FILES->{'js'}} ]->[0]->minified_url_path) =~ s/^\///r;
  $self->{'static_server'}  = ($self->{'species_defs'}->ENSEMBL_STATIC_SERVER || '') =~ s/\/$//r;
  $self->{'message'}        = encode_entities($self->{'message'}) if $self->content_type =~ /html/i && !$self->{'message_is_html'};

  return $self;
}

sub render {
  ## @override
  my $self = shift;
  return $self->_template =~ s/\[\[([^\]]+)\]\]/my $replacement = $self->{$1} || '';/ger;
}

sub _template {
  qq(<!DOCTYPE html>
<html lang="en-gb">
<head>
  <title>[[title]]</title>
  <link rel="stylesheet" type="text/css" media="all" href="[[static_server]]/[[css]]"/>
  <link rel="icon" href="[[static_server]]/i/ensembl-favicon.png" type="image/png" />
  <script type="text/javascript" src="[[static_server]]/[[js]]"></script>
</head>
<body>
  <div id="min_width_container">
    <div id="min_width_holder">
      <div id="masthead" class="js_panel">
        <div class="logo_holder"><a href="/"><div class="logo-header print_hide" title="Ensembl Home">&nbsp;</div></a></div>
      </div>
    </div>
  </div>
  <div id="main_holder">
    <div id="widemain">
      <div id="page_nav_wrapper">
        <div class="error left-margin right-margin">
          <h3>[[heading]]</h3>
          <div class="error-pad">
            <p>[[message]]</p>
            <pre>[[content]]</pre>
          </div>
        </div>
      </div>
    </div>
  </div>
</body>
</html>);
}

1;
