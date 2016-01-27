package EnsEMBL::Web::Query::Generic::GlyphSet;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Query::Generic::Base);

use List::Util qw(min max);

sub slice2sr {
  my ($self,$slice,$s,$e) = @_;

  return $slice->strand < 0 ?
    ($slice->end   - $e + 1, $slice->end   - $s + 1) : 
    ($slice->start + $s - 1, $slice->start + $e - 1);
}

sub _route {
  my ($self,$route,$data) = @_;

  my $out = $data;
  foreach my $r (@$route) {
    if($r eq '*') {
      my @new;
      push @new,@{$_||[]} for(@$out);
      $out = \@new;
    } else {
      $out = [ map { $_->{$r} } @$out ];
    }
  }
  return $out;
}

sub _remove_duds_int {
  my ($self,$route,$data) = @_;

  return $data if !@$route;
  my @rest = @$route;
  my $here = shift @rest;
  if($here eq '*') {
    my @new;
    foreach my $e (@{$data||[]}) {
      next if ref($e) eq 'HASH' and $e->{'__dud'};
      push @new,$self->_remove_duds_int(\@rest,$e);
    }
    return \@new;
  } else {
    $data->{$here} = $self->_remove_duds_int(\@rest,$data->{$here});
    return $data;
  }
}

sub _remove_duds {
  my ($self,$route,$data) = @_;

  return $self->_remove_duds_int(['*',@$route],$data);
}

sub fixup_href {
  my ($self,$key,$quick) = @_;

  if($self->phase eq 'post_process') {
    my $data = $self->data;
    foreach my $f (@$data) {
      next unless $f->{$key};
      if($quick) {
        $f->{$key} = $self->context->_quick_url($f->{$key});
      } else {
        $f->{$key} = $self->context->_url($f->{$key});
      }
    }
  }
}

sub fixup_colour {
  my ($self,$key,$default,$types,$type_key,$differs) = @_;

  $types = [$types] unless ref($types) eq 'ARRAY';
  if($self->phase eq 'post_process') {
    my $data = $self->data;
    my $gs = $self->context;
    my $cm = $gs->{'config'}{'hub'}->colourmap;
    my @route = split('/',$key);
    $key = pop @route;
    foreach my $f (@{$self->_route(\@route,$data)}) {
      next unless $f->{$key};
      $types = $f->{$type_key}||[undef] if $type_key;
      my $base_colour = $gs->my_colour($f->{$key});
      my $colour;
      foreach my $type (@$types) {
        my $c = $gs->my_colour($f->{$key},$type);
        if($c ne $base_colour or !$differs) {
          $colour = $c;
          last;
        }
      }
      $f->{$key} = $cm->hex_by_name($colour || $default);
    }
  }
}

sub fixup_label_width {
  my ($self,$key,$end_key) = @_;

  if($self->phase eq 'post_process') {
    my $data = $self->data;
    my @route = split('/',$key);
    $key = pop @route;
    foreach my $f (@{$self->_route(\@route,$data)}) {
      next unless $f->{$key};
      my $gs = $self->context;
      my $fd = $gs->get_font_details($gs->my_config('font')||'innertext',1);
      my @size = $gs->get_text_width(0,$f->{$key},'',$fd);
      $f->{$end_key} += $size[2]/$gs->scalex;
    }
  }
}

sub fixup_location {
  my ($self,$key,$slice_key,$end) = @_;

  my @route = split('/',$key);
  $key = pop @route;
  if($self->phase eq 'post_process') {
    my $data = $self->data;
    my $container = $self->context->{'container'};
    foreach my $f (@{$self->_route(\@route,$data)}) {
      $f->{$key} -= $container->start+1;
      if($end) {
        $f->{'__dud'} = 1 if $f->{$key} < 0;
        $f->{$key} = min($container->length,$f->{$key});
      } else {
        $f->{'__dud'} = 1 if $f->{$key} > $container->length;
        $f->{$key} = max($f->{$key},0);
      }
    }
    @$data = @{$self->_remove_duds(\@route,$data)};
  } elsif($self->phase eq 'post_generate') {
    my $data = $self->data;
    foreach my $f (@{$self->_route(\@route,$data)}) {
      $f->{$key} += $self->args->{$slice_key}->start+1;
    } 
  }
}

sub fixup_slice {
  my ($self,$key,$sk,$chunk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->name if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    my $ad = $self->source('Adaptors');
    if($data->{$key}) {
      $data->{$key} = $ad->slice_by_name($data->{$sk},$data->{$key});
    }
  } elsif($self->phase eq 'post_generate') {
    my $data = $self->data;
    my $ad = $self->source('Adaptors');
    foreach my $f (@$data) {
      next unless $f->{$key};
      $f->{$key} = $ad->name;
    }
  } elsif($self->phase eq 'post_process') {
    my $data = $self->data;
    my $ad = $self->source('Adaptors');
    my $sp = $self->args->{$sk};
    foreach my $f (@$data) {
      next unless $f->{$key};
      $f->{$key} = $ad->slice_by_name($sp,$f->{$key});
    }
  } elsif($self->phase eq 'split' and defined $chunk) {
    my @out;
    my $data = $self->data;
    foreach my $r (@$data) {
      my $ad = $self->source('Adaptors');
      my $all = $ad->slice_by_name($r->{$sk},$r->{$key});
      foreach my $slice (@{$self->_split_slice($all,$chunk||10_000)}) {
        my %new_r = %$r;
        $new_r{$key} = $slice->name;
        $new_r{'__name'} = $slice->name;
        push @out,\%new_r;
      }
    }
    @{$self->data} = @out;
  }
}

sub _split_slice {
  my ($self,$slice,$rsize) = @_;

  return [undef] unless defined $slice;
  my @out;
  my $rstart = int($slice->start/$rsize)*$rsize;
  while($rstart <= $slice->end) {
    push @out,Bio::EnsEMBL::Slice->new(
      -coord_system => $slice->coord_system,
      -start => $rstart,
      -end => $rstart + $rsize,
      -strand => $slice->strand,
      -seq_region_name => $slice->seq_region_name,
      -adaptor => $slice->adaptor
    );
    $rstart += $rsize;
  }
  return \@out;
}

sub fixup_config {
  my ($self,$key) = @_;

  if($self->phase eq 'pre_process') {
    use Carp qw(cluck);
    warn "FIXUP_CONFIG ".$self->phase."\n";
    my $args = $self->data;
    use Data::Dumper;
    warn Dumper($args);
    my %config;
    foreach my $k (@{$args->{$key}}) {
      $config{$k} = $self->context->my_config($k);
    }
    $args->{$key} = \%config;
  }
}

sub loop_genome {
  my ($self,$args) = @_;

  my $top = $self->source('Adaptors')->
              slice_adaptor($args->{'species'})->fetch_all('toplevel');
  my @out;
  foreach my $c (@$top) {
    my %out = %$args;
    $out{'slice'} = $c->name;
    $out{'__name'} = $c->name;
    push @out,\%out;
  } 
  return \@out;
}

1;
