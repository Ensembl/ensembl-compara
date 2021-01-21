=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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
  my ($self,$key,$slice_key,$end,$duds,$aux) = @_;

  my @route = split('/',$key);
  $key = pop @route;
  if($self->phase eq 'post_process') {
    my $data = $self->data;
    my $container = $self->context->{'container'};
    foreach my $f (@{$self->_route(\@route,$data)}) {
      if($container->strand>0) {
        $f->{$key} = $f->{$key} - $container->start + 1;
      } else {
        $f->{$key} = $container->end - $f->{$key} + 1;
      }
      if($end) {
        $f->{'__dud'} = 1 if $f->{$key} < 0 and not $duds;
        my $overhang = $f->{$key} - $container->length;
        if($overhang>0) {
          $f->{$key} -= $overhang;
          $f->{$_} -= $overhang for(@{$aux||[]});
        }
      } else {
        $f->{'__dud'} = 1 if $f->{$key} > $container->length and not $duds;
        my $underhang = -$f->{$key};
        if($underhang>0) {
          $f->{$key} += $underhang;
          $f->{$_} -= $underhang for(@{$aux||[]});
        }
      }
    }
    @$data = @{$self->_remove_duds(\@route,$data)};
  } elsif($self->phase eq 'post_generate') {
    my $data = $self->data;
    foreach my $f (@{$self->_route(\@route,$data)}) {
      my $slice = $self->args->{$slice_key};
      if($slice->strand>0) {
        $f->{$key} = $f->{$key} + $slice->start - 1;
      } else {
        $f->{$key} = $slice->end - $f->{$key} + 1;
      }
    } 
  }
}

sub fixup_alignslice {
  my ($self,$key,$sk,$chunk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    my $ass = $data->{$key};
    my $as = $ass->{'_align_slice'}; # Yuk! Checked with compara: no accessor.
    if($as) {
      $data->{$key} = {
        ref => $as->reference_Slice()->name,
        refsp => $self->context->{'config'}->hub->species,
        mlss => $as->get_MethodLinkSpeciesSet->dbID(),
	ass_species => $ass->genome_db->name,
        ass_coord => $ass->coord_system->version,
        ass_start => $ass->start,
        ass_end => $ass->end
      };
    }
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    $data->{"__orig_$key"} = $data->{$key};
    if($data->{$key}) {
      my $ad = $self->source('Adaptors');
      my $cad = $ad->compara_db_adaptor;
      my $asa = $cad->get_AlignSliceAdaptor();
      my $mlssa = $cad->get_MethodLinkSpeciesSetAdaptor();
      my $as = $asa->fetch_by_Slice_MethodLinkSpeciesSet(
        $ad->slice_by_name($data->{$key}{'refsp'},$data->{$key}{'ref'}),
        $mlssa->fetch_by_dbID($data->{$key}{'mlss'}),
        'expanded','restrict'
      );
      # try an exact match first then match except for start/end (which we fix)
      foreach my $approx ((0,1)) {
        foreach my $sl (@{$as->get_all_Slices}) {
          if($sl->coord_system->version eq $data->{$key}{'ass_coord'} and
	     $sl->genome_db->name eq $data->{$key}{'ass_species'}) {
            if($sl->start == $data->{$key}{'ass_start'} and
               $sl->end   == $data->{$key}{'ass_end'}) {
              $data->{$key} = $sl;
              return;
            }
            next unless $approx;
            # yuk, yuk, yuk! Need a way of serialising/deserialising AlSlSl
            $sl->{'start'} = $data->{$key}{'ass_start'};
            $sl->{'end'} = $data->{$key}{'ass_end'};
            $data->{$key} = $sl;
            return;
          }
        }
      }
      die "AlignSlice::Slice not found";
    }
  }
}

sub _is_align_slice {
  my ($self,$key,$sk,$chunk) = @_;

  my $data = $self->data;
  my $target;
  if($self->phase eq 'split') {
    return ref($data->[0]{'slice'}) eq 'HASH' &&
      exists $data->[0]{'slice'}{'mlss'};
  } elsif($self->phase eq 'pre_process') {
    return ref($data->{$key}) eq 'Bio::EnsEMBL::Compara::AlignSlice::Slice';
  } elsif($self->phase eq 'pre_generate') {
    return ref($data->{$key}) eq 'HASH' && exists $data->{$key}{'mlss'};
  }
}

sub fixup_slice {
  my ($self,$key,$sk,$chunk) = @_;

  if($self->_is_align_slice($key,$sk,$chunk)) {
    $self->fixup_alignslice($key,$sk,$chunk);
    return;
  }
  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->name if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    $data->{"__orig_$key"} = $data->{$key};
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

sub fixup_regulatory_feature {
  my ($self,$key,$sk,$tk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->stable_id if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    my $ad = $self->source('Adaptors');
    if($data->{$key}) {
      my $old = $data->{$key};
      $data->{$key} = $ad->regulatoryfeature_by_stableid($data->{$sk},$data->{$tk},$data->{$key});
    }
  }
}

sub fixup_epigenome {
  my ($self,$key,$sk,$tk) = @_;

  if($self->phase eq 'pre_process') {
    my $data = $self->data;
    $data->{$key} = $data->{$key}->name if $data->{$key};
  } elsif($self->phase eq 'pre_generate') {
    my $data = $self->data;
    my $ad = $self->source('Adaptors');
    if($data->{$key}) {
      $data->{$key} = $ad->epigenome_by_stableid($data->{$sk},$data->{$tk},$data->{$key});
    }
  }
}

sub fixup_loci {
  my ($self,$key,$fk) = @_;

  my $args = $self->args;
  if($self->phase eq 'post_generate') {
    return unless defined $args->{$fk};
    my $data = $self->data;
    my $offset = $args->{$fk}->slice->start-1;
    foreach my $d (@$data) {
      $d->{$key} += $offset;
    }
  } elsif($self->phase eq 'post_process') {
    return unless defined $args->{$fk};
    my $data = $self->data;
    my $offset = $args->{$fk}->slice->start-1;
    foreach my $d (@$data) {
      $d->{$key} -= $offset;
    }
  }
}

sub _split_slice {
  my ($self,$slice,$rsize) = @_;

  return [undef] unless defined $slice;
  my @out;
  my $rstart = int($slice->start/$rsize)*$rsize+1;
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
    my $args = $self->data;
    my %config;
    foreach my $k (@{$args->{$key}}) {
      $config{$k} = $self->context->my_config($k);
    }
    $args->{$key} = \%config;
  }
}

sub loop_genome {
  my ($self,$args,$subpart) = @_;

  my $top = $self->source('Adaptors')->
              slice_adaptor($args->{'species'})->fetch_all('toplevel');
  my @out;
  foreach my $c (@$top) {
    my %out = %$args;
    $out{'slice'} = $c->name;
    $out{'__name'} = $c->name;
    push @out,\%out;
  }
  $self->get_defaults($args->{'species'},'core','MultiBottom');
  return \@out;
}

sub loop_regulatoryfeature {
  my ($self,$args,$subpart) = @_;

  my @out;
  my $rfa = $self->source('Adaptors')->
              regulatory_feature_adaptor($args->{'species'},$args->{'type'});
  my $all = $rfa->fetch_all;
  foreach my $r (@$all) {
    next if ($subpart->{'feature'}||$r->stable_id) ne $r->stable_id;
    next unless $r->stable_id;
    my %out = %$args;
    $out{'feature'} = $r->stable_id;
    $out{'__name'} = $r->stable_id;
    push @out,\%out;
  }
  return \@out;
}

sub get_defaults {
  my ($self,$species,$type,$view,$tables) = @_;

  my $sd = $self->source('SpeciesDefs');
  $tables ||= $sd->all_tables($species,$type);
  my %out;
  foreach my $table (@$tables) {
    my $ti = $sd->table_info($species,$type,$table);
    next unless $ti->{'analyses'};
    foreach my $an (keys %{$ti->{'analyses'}}) {
      next unless $ti->{'analyses'}{$an}{'disp'};
      my $def = $ti->{'analyses'}{$an}{'web'}{'default'};
      next unless $def and $def->{$view};
      $out{$an} = $def->{$view};
    }
  }
  return \%out;
}

1;
