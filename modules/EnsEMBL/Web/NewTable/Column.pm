=head1 sLICENSE

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

package EnsEMBL::Web::NewTable::Column;

use strict;
use warnings;

use Carp;
use Scalar::Util qw(weaken);
use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

sub new {
  my ($proto,$config,$type,$key,$confarr,$confarg) = @_;

  my $class = "EnsEMBL::Web::NewTable::Column";
  $class .= "::".ucfirst($type) if $type;
  dynamic_require($class);

  my $self = {
    config => $config,
    key => $key,
    type => $type,
    label => $key,
    decoration => {},
    conf => {
      width => "100u",
      primary => 0,
      sort => 1,
      incr_ok => 0,
      sstype => $type,
      ssconf => $confarr,
      ssarg => $confarg,
    },
  };
  weaken($self->{'config'});

  bless $self, $class;
  $self->init();
  $self->{'conf'}{'type_js'} = $self->js_type();
  $self->{'conf'}{'range'} = $self->js_range();
  $self->configure($confarr,$confarg);
  return $self;
}

sub init {}

# \f -- optional hyphenation point
# \a -- optional break point (no hyphen)
sub hyphenate {
  local $_ = $_[0];
  s/\f/&shy;/g;
  s/\a/&#8203;/g;
  return $_;
}

sub clean { return $_[1]; }
sub null { return 0; }

sub key { return $_[0]->{'key'}; }

sub decorate {
  my ($self,$type,$prio) = @_;

  $prio ||= 50;
  $self->{'decoration'}{$type} = $prio;
  $self->{'conf'}{'decorate'} = [
    sort { $self->{'decoration'}{$a} <=> $self->{'decoration'}{$b} }
    keys %{$self->{'decoration'}}
  ];
}

sub set_type {
  my ($self,$key,$value) = @_;

  $self->{'conf'}{'type'} ||= {};
  $self->{'conf'}{'type'}{$key} = $value;
}

sub set_heading {
  my ($self,$key,$value) = @_;

  $self->{'conf'}{'heading'} ||= {};
  $self->{'conf'}{'heading'}{$key} = $value;
}

sub set_helptip {
  my ($self,$help) = @_;

  $self->{'conf'}{'help'} = $help;
}

sub set_label {
  my ($self,$label) = @_;

  $self->{'label'} = $label;
  $self->{'conf'}{'label'} = hyphenate($label);
}

sub get_label { return $_[0]->{'label'}; }

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

  $a = '' unless defined $a;
  $b = '' unless defined $b;
  my $av = $self->clean($a);
  my $bv = $self->clean($b);
  my $an = $self->is_null($av);
  my $bn = $self->is_null($bv);
  return $an-$bn if $an-$bn;
  return $self->cmp($av,$bv,$f,$cache,$keymeta,$col);
}

sub split { return [$_[0]->clean($_[1])]; }

sub match {
  my ($self,$range,$value) = @_;

  foreach my $x (keys %$range) {
    return 0 if lc $x eq lc $value;
  }
  return 1;
}
sub range { return $_[1]||{}; }

sub is_match {
  my ($self,$x,$y) = @_;

  return 0 unless defined $y;
  return $self->match($x,$y);
}

sub add_value {
  my ($self,$range,$value) = @_;

  return unless defined $value;
  my $values = $self->split($value);
  return unless defined $values;
  foreach my $v (@$values) {
    $self->has_value($range,$v) if defined $v;
  }
}

sub colconf { return $_[0]->{'conf'}; }
sub set_primary { $_[0]->{'conf'}{'primary'} = $_[1]; }
sub no_sort { $_[0]->{'conf'}{'sort'} = 0; }
sub set_filter { $_[0]->{'conf'}{'range'} = $_[1]; }
sub no_filter { $_[0]->set_filter(''); }

sub unshowable { $_[0]->set_type('screen',{ unshowable => 1 }); }
sub sort_for { $_[0]->set_type('sort_for',{ col => $_[1] }); }
sub sort_down_first { $_[0]->set_type('sort_down',$_[1]); }

sub configure {
  my ($self,$mods,$args) = @_;

  foreach my $mod (@{$mods||[]}) {
    if($self->can($mod)) { $self->$mod(); }
    else { die "Bad argument '$mod'"; }
  }
  foreach my $k (keys %$args) {
    my $v = $args->{$k};
    my @names = ($k,"set_$k");
    push @names,$k if $k =~ s/_/_set_/;
    my $ok = 0;
    foreach my $fn (@names) {
      if($self->can($fn)) { $self->$fn($v); $ok=1; last; }
    }
    confess "Bad option '$names[0]' for $self ($self->{'config'})" unless $ok;
  }
}

sub can {
  my ($self,$fn) = @_;

  return 1 if $self->SUPER::can($fn);
  return $self->{'config'}->can_delegate('col',$fn);
}

# For things defined in plugins. Maybe use roles in future?
sub AUTOLOAD {
  our $AUTOLOAD;
  my $fn = $AUTOLOAD;
  $fn =~ s/^.*:://;
  my $self = shift;

  return $self->{'config'}->delegate($self,'col',$fn,\@_);
}
sub DESTROY {} # For AUTOLOAD

1;
