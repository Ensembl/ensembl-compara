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

use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Decorate;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(DecorateIconic DecorateLink DecorateEditorial
                          DecorateAlso DecorateToggle DecorateRecolour
                          DecorateFancyPosition)]; }
sub decorate_key { return undef; }
sub js_plugin {
  my $dk = $_[0]->decorate_key()||'';
  $dk = "_$dk" if $dk;
  return "newtable_decorate$dk";
}
sub requires {
  my $dk = $_[0]->decorate_key();
  if(defined $dk) { return ['Decorate'] } else { return children(); }
}

sub set_decorates {
  my ($self,$col,$cval,$data) = @_;

  my $pkey = $self->decorate_key();
  $self->config->add_keymeta("decorate/$pkey",$col,$cval,$data);
  $col->decorate($self->decorate_key);
}

package EnsEMBL::Web::NewTable::Plugins::DecorateIconic;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(HelpTips)]; }

sub init {
 $_[0]->{'colourmap'} = $_[0]->hub->colourmap;
}

sub decorate_key { return 'iconic'; }

sub col_icon_url {
  $_[0]->set_decorates($_[1],$_[2],{ icon => $_[3] });
}

sub col_icon_helptip {
  $_[0]->set_decorates($_[1],$_[2],{ helptip => $_[3] });
}

sub col_icon_export {
  $_[0]->set_decorates($_[1],$_[2],{ export => $_[3] });
}

sub col_icon_order {
  $_[0]->set_decorates($_[1],$_[2],{ order => $_[3] });
}

sub col_icon_coltab {
  my $col = $_[0]->{'colourmap'}->hex_by_name($_[3]);
  $_[0]->set_decorates($_[1],$_[2],{ coltab => $col });
}

sub col_icon_source {
  $_[0]->set_decorates($_[1],'*',{ icon_source => $_[2] });
}

package EnsEMBL::Web::NewTable::Plugins::DecorateLink;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'link'; }

sub col_link_url {
  my ($self,$col,$spec) = @_;
  my (%base,%params,$base);
  if($spec->{'__external'}) {
    $base = $spec->{'__external'};
    delete $spec->{'__external'};
  }
  foreach my $k (keys %$spec) {
    if(ref($spec->{$k}) eq 'ARRAY') { $params{$k} = $spec->{$k}[0]; }
    else { $base{$k} = $spec->{$k}; }
  }
  unless($base) {
    $base = $self->hub->url(\%base);
  }
  $self->set_decorates($col,'*',{ base_url => $base, params => \%params});
}

sub col_url_column {
  my ($self,$col,$value) = @_;

  $self->set_decorates($col,'*',{ url_column => $value });
}

sub col_title_column {
  my ($self,$col,$value) = @_;

  $self->set_decorates($col,'*',{ title_column => $value });
}

sub col_extra_column {
  my ($self,$col,$value) = @_;

  $self->set_decorates($col,'*',{ extra_column => $value });
}

sub col_url_rel {
  my ($self,$col,$value) = @_;

  $self->set_decorates($col,'*',{ url_rel => $value });
}


package EnsEMBL::Web::NewTable::Plugins::DecorateEditorial;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'editorial'; }

sub col_editorial_type {
  $_[0]->set_decorates($_[1],'*',{ type => $_[2] });
}

sub col_editorial_source {
  $_[0]->set_decorates($_[1],'*',{ source => $_[2] });
}

sub col_editorial_cssclass {
  $_[0]->set_decorates($_[1],$_[2],{ cssclass => $_[3] });
}

sub col_editorial_helptip {
  $_[0]->set_decorates($_[1],$_[2],{ helptip => $_[3] });
}

package EnsEMBL::Web::NewTable::Plugins::DecorateAlso;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'also'; }

sub col_also_cols {
  my ($self,$col,$cols) = @_;

  $cols = [ $cols ] unless ref($cols) eq 'ARRAY';
  $self->set_decorates($col,'*',{ cols => $cols });
}

package EnsEMBL::Web::NewTable::Plugins::DecorateRecolour;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'recolour'; }

sub col_recolour {
  my ($self,$col,$colours) = @_;

  $self->set_decorates($col,'*',{ recolour => $colours });
}

package EnsEMBL::Web::NewTable::Plugins::DecorateFancyPosition;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'fancy_position'; }

sub col_fancy_position  {
  my ($self,$col,$fancy) = @_;

  $self->set_decorates($col,'*',{ fancy_position => $fancy });
}

package EnsEMBL::Web::NewTable::Plugins::DecorateToggle;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'toggle'; }

sub col_toggle_set_separator {
  $_[0]->set_decorates($_[1],'*',{ separator => $_[2] });
}

sub col_toggle_set_maxlen {
  $_[0]->set_decorates($_[1],'*',{ max => $_[2] });
}

sub col_toggle_highlight_column {
  $_[0]->set_decorates($_[1],'*',{ highlight_col => $_[2] });
}

sub col_toggle_highlight_over {
  $_[0]->set_decorates($_[1],'*',{ highlight_over => $_[2] });
}

sub col_toggle_highlight_position {
  $_[0]->set_decorates($_[1],'*',{ highlight_pos => $_[2] });
}

1;
