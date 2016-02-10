=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Query::GlyphSet::Transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 5;

use List::Util qw(min max);

sub fixup {
  my ($self) = @_;

  $self->fixup_slice('slice','species',100_000);
  $self->fixup_location('start','slice',0);
  $self->fixup_location('end','slice',1);
  $self->fixup_unique('_unique');
  $self->_fixup_label();
  $self->_fixup_href();
}

sub _colour_key {
  my ($self,$args,$gene,$transcript) = @_;

  $transcript ||= $gene;
  my $pattern = $args->{'pattern'} || '[biotype]';
  
  # hate having to put ths hack here, needed because any logic_name
  # specific web_data entries get lost when the track is merged - needs
  # rewrite of imageconfig merging code
  return 'merged' if $transcript->analysis->logic_name =~ /ensembl_havana/;

  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' ? $transcript->analysis->$1 : $transcript->$1/eg;

  return lc $pattern;
}

sub _fixup_label {
  my ($self) = @_;

  if($self->phase eq 'post_process') {
    my $gs = $self->context;
    foreach my $f (@{$self->data}) {
      my $ini_entry = $gs->my_colour($f->{'colour_key'},'text');
      $f->{'label'} =~ s/\[text_label\]/$ini_entry/g;
    }
  }
}

sub _feature_label {
  my ($self,$args,$gene,$transcript) = @_;

  $transcript ||= $gene;

  my $id = $transcript->external_name || $transcript->stable_id;
  $id = $transcript->strand == 1 ? "$id >" : "< $id";
  
  return $id if $args->{'shortlabels'} || $transcript == $gene;  
  my $label = $args->{'label_key'} || '[text_label] [display_label]';
  
  return $id if $label eq '-';
  
  if ($label =~ /[biotype]/) {
    my $biotype = $transcript->biotype;
       $biotype =~ s/_/ /g;
       $label   =~ s/\[biotype\]/$biotype/g;
  }
  
  $label =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $gene->analysis->$1 : $gene->$1/eg;
  $label =~ s/\[(\w+)\]/$1 eq 'logic_name' || $1 eq 'display_label' ? $transcript->analysis->$1 : $transcript->$1/eg;
  
  $id .= "\n$label" unless $label eq '-';
  
  return $id;
}

sub _get_genes {
  my ($self,$args) = @_;
  
  my $slice          = $args->{'slice'};
  my $analyses       = $args->{'logic_names'};
  my $db_alias       = $args->{'db'};

  if ($analyses->[0] eq 'LRG_import' &&
      !$slice->isa('Bio::EnsEMBL::LRGSlice')) {
    my $lrg_slices = $slice->project('lrg');
    if ($lrg_slices->[0]) {
      my $lrg_slice = $lrg_slices->[0]->to_Slice;
      return [map @{$lrg_slice->get_all_Genes($_,$db_alias) || []}, @$analyses];
    }
  } elsif ($slice->isa('Bio::EnsEMBL::LRGSlice') && $analyses->[0] ne 'LRG_import') {
    return [map @{$slice->feature_Slice->get_all_Genes($_, $db_alias) || []}, @$analyses];
  } else {
    return [map @{$slice->get_all_Genes($_,$db_alias) || []}, @$analyses];
  }
}

sub _fixup_href {
  my ($self) = @_; 

  if($self->phase eq 'post_process') {
    my $gs = $self->context;
    my $hub = $gs->{'config'}->hub;
    my $calling_sp = $hub->species;
    my $multi_params = $hub->multi_params;
    my $action = $gs->my_config('zmenu') // $hub->action;
    my $r = $hub->param('r');
    foreach my $f (@{$self->data}) {
      my $p = {
        %$multi_params,
        %{$f->{'href'}},
        action => $action,
        calling_sp => $calling_sp,
        real_r => $r,
      };
      if($gs->{'container'}{'web_species'} ne $gs->species) {
        $p->{'r'} = undef;
      }
      $f->{'href'} = $gs->_url($p);
    }
  }
}

sub _href {
  my ($self,$args,$gene,$transcript) = @_; 
  my $params = { 
    species    => $args->{'species'},
    type       => $transcript ? 'Transcript' : 'Gene',
    g          => $gene->stable_id,
    db         => $args->{'db'},
  };  

  $params->{'t'} = $transcript->stable_id if $transcript;
  return $params;
}

sub get {
  my ($self,$args) = @_;

  my @out;
  my $genes = $self->_get_genes($args);
  foreach my $g (@$genes) {
    my $title = sprintf("Gene: %s; Location: %s:%s-%s",
                        $g->stable_id,$g->seq_region_name,
                        $g->seq_region_start,$g->seq_region_end);
    $title = $g->external_name.'; ' if $g->external_name;

    push @out,{
      _unique => $g->dbID,
      start => $g->start,
      end => $g->end,
      href => $self->_href($args,$g),
      title => $title,
      label => $self->_feature_label($args,$g),
      colour_key => $self->_colour_key($args,$g),
      strand => $g->strand,
      stable_id => $g->stable_id,
    };
  }
  return \@out;
}

1;
