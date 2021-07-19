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

sub filter_saved {
  my ($config,$data) = @_;

  foreach my $key (@{$config->columns}) {
    my $col = $config->column($key);
    next unless $col->colconf->{'state_filter_ephemeral'};
    delete $data->{'filter'}{$key};
  }
  delete $data->{'filter'} unless %{$data->{'filter'}};
}

sub col_state_filter_ephemeral {
  my ($self,$col,$yn) = @_;

  $col->colconf->{'state_filter_ephemeral'} = $yn;
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

sub col_filter_slider_class {
  my ($self,$col,$class) = @_;

  $self->config->add_keymeta("filter",$col,'*',{
    slider_class => $class
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
