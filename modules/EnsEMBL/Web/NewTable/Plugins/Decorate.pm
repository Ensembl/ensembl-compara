use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Decorate;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(DecorateIconic DecorateLink DecorateEditorial
                          DecorateAlso DecorateToggle)]; }
sub requires { return children(); }
sub decorate_key { return undef; }
sub js_plugin {
  my $dk = $_[0]->decorate_key();
  $dk = "_$dk" if $dk;
  return "newtable_decorate$dk";
}

sub set_decorates {
  my ($self,$col,$cval,$data) = @_;

  my $pkey = $self->decorate_key();
  $self->{'table'}->register_key("decorate/$pkey/$col/$cval",$data);
}

sub value {
  my ($self,$column,$value) = @_;

  return EnsEMBL::Web::NewTable::Plugins::Decorate::Value
    ->_new($self,$column,$value);
}

sub column { return $_[0]->value($_[1],'*'); }

package EnsEMBL::Web::NewTable::Plugins::Decorate::Value;

sub _new {
  my ($proto,$plugin,$columns,$values) = @_;

  $columns = [ $columns ] unless ref($columns) eq 'ARRAY';
  $values = [ $values ] unless ref($values) eq 'ARRAY';
  my $class = ref($proto) || $proto;
  my $self = {
    plugin => $plugin,
    columns => $columns,
    values => $values,
  };
  my $pkg = ref($self->{'plugin'});
  bless $self,"${pkg}::Value";
  $self->init();
  return $self;
}

sub init {}
sub set_decorates {
  my ($self,$data) = @_;

  foreach my $column (@{$self->{'columns'}}) {
    foreach my $value (@{$self->{'values'}}) {
      $self->{'plugin'}->set_decorates($column,$value,$data);
    }
  }
}

package EnsEMBL::Web::NewTable::Plugins::DecorateIconic;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(Decorate)]; }
sub decorate_key { return 'iconic'; }

package EnsEMBL::Web::NewTable::Plugins::DecorateIconic::Value;
our @ISA = qw(EnsEMBL::Web::NewTable::Plugins::Decorate::Value);

sub init {
 $_[0]->{'colourmap'} = $_[0]->{'plugin'}->table->component->hub->colourmap;
}

sub set_icon { $_[0]->set_decorates({ icon => $_[1] }); }
sub set_helptip { $_[0]->set_decorates({ helptip => $_[1] }); }
sub set_export { $_[0]->set_decorates({ export => $_[1] }); }
sub set_order { $_[0]->set_decorates({ order => $_[1] }); }
sub set_coltab {
  my $col = $_[0]->{'colourmap'}->hex_by_name($_[1]);
  $_[0]->set_decorates({ coltab => $col });
}

package EnsEMBL::Web::NewTable::Plugins::DecorateLink;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(Decorate)]; }
sub decorate_key { return 'link'; }

package EnsEMBL::Web::NewTable::Plugins::DecorateLink::Value;
our @ISA = qw(EnsEMBL::Web::NewTable::Plugins::Decorate::Value);

sub set_url {
  $_[0]->set_decorates({ base_url => $_[1], params => $_[2]||{}});
}

package EnsEMBL::Web::NewTable::Plugins::DecorateEditorial;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(Decorate)]; }
sub decorate_key { return 'editorial'; }

package EnsEMBL::Web::NewTable::Plugins::DecorateEditorial::Value;
our @ISA = qw(EnsEMBL::Web::NewTable::Plugins::Decorate::Value);

sub set_css_class { $_[0]->set_decorates({ cssclass => $_[1] }); }
sub set_helptip { $_[0]->set_decorates({ helptip => $_[1] }); }
sub set_type { $_[0]->set_decorates({ type => $_[1] }); }
sub set_source { $_[0]->set_decorates({ source => $_[1]->key() }); }

package EnsEMBL::Web::NewTable::Plugins::DecorateAlso;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(Decorate)]; }
sub decorate_key { return 'also'; }

package EnsEMBL::Web::NewTable::Plugins::DecorateAlso::Value;
our @ISA = qw(EnsEMBL::Web::NewTable::Plugins::Decorate::Value);

sub set_cols { $_[0]->set_decorates({ cols => $_[1] }); }

package EnsEMBL::Web::NewTable::Plugins::DecorateToggle;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(Decorate)]; }
sub decorate_key { return 'toggle'; }

package EnsEMBL::Web::NewTable::Plugins::DecorateToggle::Value;
our @ISA = qw(EnsEMBL::Web::NewTable::Plugins::Decorate::Value);

sub set_separator { $_[0]->set_decorates({ separator => $_[1] }); }
sub set_maxlen { $_[0]->set_decorates({ max => $_[1] }); }
sub set_highlight_column {
  $_[0]->set_decorates({ hightlight_col => $_[1]->key() });
}
sub set_highlight_over {$_[0]->set_decorates({ highlight_over => $_[1] });}

1;
