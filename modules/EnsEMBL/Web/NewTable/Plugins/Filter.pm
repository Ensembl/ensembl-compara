use strict;
use warnings;

package EnsEMBL::Web::NewTable::Plugins::Filter;
use parent qw(EnsEMBL::Web::NewTable::Plugin);

sub children { return [qw(FilterClass FilterRange)]; }
sub requires { return [@{children()},'Types']; }
sub js_plugin { return "new_table_filter"; }
sub position{ return [qw(controller)]; }

sub col_filter_label {
  my ($self,$col,$label) = @_;

  $col->colconf->{'filter_label'} = $label;
}

sub col_filter_sorted {
  my ($self,$col,$yn) = @_;

  $col->colconf->{'filter_sorted'} = $yn;
}

sub col_filter_keymeta_enum {
  my ($self,$col,$yn) = @_;

  $self->config->add_keymeta("enumerate",$col,'*',{
    from_keymeta => $yn
  });
}

package EnsEMBL::Web::NewTable::Plugins::FilterClass;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Filter);

sub js_plugin { return "newtable_filter_class"; }
sub requires { return [qw(Filter)]; }

package EnsEMBL::Web::NewTable::Plugins::FilterRange;
use parent qw(EnsEMBL::Web::NewTable::Plugins::Filter);

sub js_plugin { return "newtable_filter_range"; }
sub requires { return [qw(Filter)]; }

sub col_filter_range {
  my ($self,$col,$minmax) = @_;

  $self->config->add_keymeta("enumerate",$col,'*',{
    merge => {
      min => $minmax->[0],
      max => $minmax->[1]
    }
  });
}

sub col_filter_seq_range {
  my ($self,$col,$chr,$minmax) = @_;

  $self->config->add_keymeta("enumerate",$col,'*',{
    merge => {
      $chr => {
        min => $minmax->[0],
        max => $minmax->[1]
      }
    }
  });
}

sub col_filter_integer {
  my ($self,$col,$yn) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    integer => $yn,
  });
}

sub col_filter_blank_button {
  my ($self,$col,$yn) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    blank_button => $yn,
  });
}

sub col_filter_fixed {
  my ($self,$col,$yn) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    fixed => $yn,
  });
}

sub col_filter_logarithmic {
  my ($self,$col,$yn) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    logarithmic => $yn,
  });
}

sub col_filter_maybe_blank {
  my ($self,$col,$yn) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    maybe_blank => $yn,
  });
}

sub col_filter_endpoint_markup {
  my ($self,$col,$left_right,$html) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    ($left_right?'endpoint_right':'endpoint_left') => $html,
  });
}

sub col_filter_add_baked {
  my ($self,$col,$key,$name,$tooltip) = @_;

  my $meta = $self->config->get_keymeta("filter",$col,'*');
  my $baked = ($meta->{'bakery'}||=[]);
  push @$baked,{
    key => $key,
    label => ($name||$key),
    helptip => $tooltip
  };
}

sub col_filter_add_bakefoot {
  my ($self,$col,$text) = @_;

  my $meta = $self->config->get_keymeta("filter",$col,'*');
  my $bakefoot = ($meta->{'bakefoot'}||=[]);
  push @$bakefoot,$text;
}

sub col_filter_bake_into {
  my ($self,$col,$value,$button) = @_;

  my $meta = $self->config->get_keymeta("filter",$col,$value);
  my $baked = ($meta->{'baked'}||=[]);
  push @$baked,$button;
}

1;
