use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Decorate;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(DecorateIconic DecorateLink DecorateEditorial
                          DecorateAlso DecorateToggle)]; }
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
  my $colkey = $col->key();
  $self->{'table'}->register_key("decorate/$pkey/$colkey/$cval",$data);
  $col->decorate($self->decorate_key);
}

package EnsEMBL::Web::NewTable::Plugins::DecorateIconic;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub requires { return [qw(HelpTips)]; }

sub init {
 $_[0]->{'colourmap'} = $_[0]->table->hub->colourmap;
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

package EnsEMBL::Web::NewTable::Plugins::DecorateLink;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Decorate);

sub decorate_key { return 'link'; }

sub col_link_url {
  my ($self,$col,$spec) = @_;
  my (%base,%params);
  foreach my $k (keys %$spec) {
    if(ref($spec->{$k}) eq 'ARRAY') { $params{$k} = $spec->{$k}[0]; }
    else { $base{$k} = $spec->{$k}; }
  }
  my $base = $self->table->hub->url(\%base);
  $self->set_decorates($col,'*',{ base_url => $base, params => \%params});
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

1;
