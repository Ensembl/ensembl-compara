=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::Column;

use strict;
use warnings;

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub new {
  my ($proto,$table,$type,$key) = @_;

  my $class = "EnsEMBL::Web::NewTable::Column";
  $class .= "::".ucfirst($type) if $type;
  dynamic_require($class);

  my $self = {
    table => $table,
    key => $key,
    type => $type,
    conf => {
      width => "100u",
      primary => 0,
      sort => 1,
      incr_ok => 1,
      sstype => $type,
    },
  };

  bless $self, $class;
  $self->{'conf'}{'type_js'} = $self->js_type();
  $self->{'conf'}{'range'} = $self->js_range();
  $self->{'conf'}{'range_params'} = $self->js_params();
  return $self;
}

sub js_params { return {}; }
sub clean { return $_[1]; }
sub null { return 0; }

sub key { return $_[0]->{'key'}; }

sub value {
  my ($self,$plugin_name,$value) = @_;

  $value ||= '*';
  my $plugin = $self->{'table'}->get_plugin($plugin_name);
  return $plugin->value($self,$value);
}

sub decorate {
  my ($self,$type) = @_;

  $self->{'conf'}{'decorate'} = $type;
}

sub set_type {
  my ($self,$key,$value) = @_;

  $self->{'conf'}{'type'} ||= {};
  $self->{'conf'}{'type'}{$key} = $value;
}

sub set_helptip {
  my ($self,$help) = @_;

  $self->{'conf'}{'help'} = $help;
}

sub set_label {
  my ($self,$label) = @_;

  $self->{'conf'}{'label'} = $label;
}

sub set_width {
  my ($self,$mul) = @_;

  $self->{'conf'}{'width'} = ($mul*100)."u";
}

sub is_null {
  my ($self,$value) = @_;

  return 1 unless defined $value;
  $value = $self->clean($value);
  return 1 unless defined $value;
  return !!($self->null($value));
}

sub compare {
  my ($self,$a,$b,$f,$keymeta,$cache,$col) = @_;

  my $av = $self->clean($a||'');
  my $bv = $self->clean($b||'');
  my $an = $self->is_null($av);
  my $bn = $self->is_null($bv);
  return $an-$bn if $an-$bn;
  return $self->cmp($av,$bv,$f,$cache,$keymeta,$col);
}

sub set_range { $_[0]->{'conf'}{'range_range'} = $_[1]; }
sub set_primary { $_[0]->{'conf'}{'primary'} = 1; }
sub no_sort { $_[0]->{'conf'}{'sort'} = 0; }
sub set_filter { $_[0]->{'conf'}{'range'} = $_[1]; }
sub no_filter { $_[0]->set_filter(''); }

sub colconf { return $_[0]->{'conf'}; }

1;
