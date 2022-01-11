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

package EnsEMBL::Web::Query::GlyphSet::Transcript;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 13;

use JSON;
use List::Util qw(min max);
use Bio::EnsEMBL::Gene;

sub precache {
  return {
    ccds => {
      loop => ['species','genome'],
      args => {
        db => "otherfeatures",
        pattern => "[logic_name]",
        label_key => "[biotype]",
        logic_names => ["ccds_import"],
        shortlabels => '',
      }
    },
    transcript => {
      loop => ['species','genome'],
      args => {
        db => "core",
        logic_names => sub {
          my ($self,$args) = @_;

          return [ sort keys %{$self->get_defaults($args->{'species'},'core','MultiBottom',['gene'])} ];
        },
        label_key => '[biotype]',
        pattern => '[biotype]',
        shortlabels => '',
      }
    },
    gencode => {
      loop => ['species','genome'],
      args => {
        logic_names => [qw(
          assembly_patch_ensembl    ensembl      ensembl_havana_gene
          ensembl_havana_ig_gene    ensembl_havana_lincrna
          ensembl_lincrna           havana       havana_ig_gene
          mt_genbank_import         ncrna        proj_ensembl
          proj_ensembl_havana_gene  proj_ensembl_havana_ig_gene
          proj_ensembl_havana_lincrna   proj_havana
          proj_havana_ig_gene       proj_ncrna
        )],
        label_key => "[biotype]",
        only_attrib => "gencode_basic",
        shortlabels => '',
      }
    },
    genscan => {
      loop => ['species','genome'],
      args => {
        db => "core",
        logic_names => ['genscan'],
        label_key => "[display_label]",
        pattern => "genscan",
        prediction => 1,
        shortlabels => '',
      }
    },
  };
}

sub fixup {
  my ($self) = @_;

  $self->fixup_slice('slice','species',100_000);
  $self->fixup_location('start','slice',0);
  $self->fixup_location('end','slice',1);
  $self->fixup_location('transcripts/*/start','slice',0);
  $self->fixup_location('transcripts/*/end','slice',1);
  $self->fixup_location('transcripts/*/exons/*/start','slice',0,1,['coding_start']);
  $self->fixup_location('transcripts/*/exons/*/end','slice',1,1,['coding_end']);
  $self->fixup_unique('_unique');
  $self->fixup_unique('transcripts/*/_unique');
  $self->fixup_unique('transcripts/*/exons/*/_unique');
  $self->_fixup_label('label');
  $self->_fixup_label('transcripts/*/label');
  $self->_fixup_href('href');
  $self->_fixup_href('transcripts/*/href');
}

sub _colour_key {
  my ($self,$args,$gene,$transcript) = @_;

  $transcript ||= $gene;
  my $pattern = $args->{'pattern'} || '[biotype]';
  
  # hate having to put ths hack here, needed because any logic_name
  # specific web_data entries get lost when the track is merged - needs
  # rewrite of imageconfig merging code
  return 'merged' if $transcript->analysis and $transcript->analysis->logic_name =~ /ensembl_havana/;

  $pattern =~ s/\[gene.(\w+)\]/$1 eq 'logic_name' ? $gene->analysis->$1 : $gene->$1/eg;
  $pattern =~ s/\[(\w+)\]/$1 eq 'logic_name' ? $transcript->analysis->$1 : $transcript->$1/eg;

  return lc $pattern;
}

sub _fixup_label {
  my ($self,$key) = @_;

  if($self->phase eq 'post_process') {
    my $gs = $self->context;
    my @route = split('/',$key);
    $key = pop @route;
    my $route = $self->_route(\@route,$self->data);
    foreach my $f (@$route) {
      my $ini_entry = $gs->my_colour($f->{'colour_key'},'text');
      $f->{'label'} =~ s/\[text_label\]/$ini_entry/g;
    }
  }
}

sub _feature_label {
  my ($self,$args,$gene,$transcript) = @_;

  $transcript ||= $gene;


  my $id = '';

  if( $transcript->external_name && $transcript->stable_id){
    $id = $transcript->external_name . " - " . $transcript->stable_id;
  } else {
    $id = $transcript->external_name || $transcript->stable_id;
  }
  
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

sub _fake_gene {
  my ($self, $transcript) = @_;
  my $gene = Bio::EnsEMBL::Gene->new;

  $gene->add_Transcript($transcript);
  $gene->stable_id($transcript->stable_id); # fake a stable id so that the data structures returned by features are correct.

  return $gene;
}

sub _get_prediction_transcripts {
  my ($self,$args) = @_;

  my $slice = $args->{'slice'};
  my $db_alias = $args->{'db'};
  my @out;
  my $is_gencode_basic = $args->{'only_attrib'} eq 'gencode_basic' ? 1 : 0;

  foreach my $logic_name (@{$args->{'logic_names'}}) {
    my $logic_name_with_species = $is_gencode_basic ?  $logic_name.'_'.$args->{'species'} : $logic_name;

    my @t = @{$slice->get_all_PredictionTranscripts($logic_name_with_species,$db_alias)};
    my @g = map { $self->_fake_gene($_) } @t;
    push @out,@g;
  }
  return \@out;
}

sub _get_genes {
  my ($self,$args) = @_;
  
  my $slice          = $args->{'slice'};
  my $analyses       = $args->{'logic_names'};
  my $db_alias       = $args->{'db'};
  my $species        = $args->{'species'};
  my $only_attrib    = $args->{'only_attrib'} || '' ;
  my $is_gencode_basic = $only_attrib eq 'gencode_basic' ? 1 : 0;

  if ($analyses->[0] eq 'LRG_import' && !$slice->isa('Bio::EnsEMBL::LRGSlice')) {
    warn "!!! DEPRECATED CODE - please change this track to use GlyphSet::lrg";
    my $lrg_slices = $slice->project('lrg');
    if ($lrg_slices->[0]) {
      my $lrg_slice = $lrg_slices->[0]->to_Slice;
      return [map @{$lrg_slice->get_all_Genes($is_gencode_basic ? $_.'_'. $species : $_,$db_alias) || []}, @$analyses];
    }
  } elsif ($slice->isa('Bio::EnsEMBL::LRGSlice') && $analyses->[0] ne 'LRG_import') {
    return [map @{$slice->feature_Slice->get_all_Genes($is_gencode_basic ? $_.'_'.$species : $_, $db_alias) || []}, @$analyses];
  } else {
    return [map @{$slice->get_all_Genes($is_gencode_basic ? $_.'_'.$species : $_,$db_alias) || []}, @$analyses];
  }
}

sub _fixup_href {
  my ($self,$key) = @_; 

  if($self->phase eq 'post_process') {
    my $gs = $self->context;
    my $hub = $gs->{'config'}->hub;
    my $calling_sp = $hub->species;
    my $multi_params = $hub->multi_params;
    my $action = $gs->my_config('zmenu') // $hub->action;
    my $r = $hub->param('r');
    my @route = split('/',$key);
    $key = pop @route;
    my $route = $self->_route(\@route,$self->data);
    foreach my $f (@$route) {
      my $p = {
        %$multi_params,
        %{$f->{'href'}},
        action => $action,
        calling_sp => $calling_sp,
        real_r => $r,
      };
      if($gs->{'container'} and $gs->{'container'}{'web_species'} and
         $gs->species and
         $gs->{'container'}{'web_species'} ne $gs->species) {
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

  if($args->{'prediction'}) {
    $params->{'pt'} = $transcript->stable_id if $transcript;
    $params->{'g'} = undef;
  } else {
    $params->{'t'} = $transcript->stable_id if $transcript;
  }
  return $params;
}

sub _unique {
  my ($self,$args,$obj) = @_;

  if(ref($args->{'slice'}) eq 'Bio::EnsEMBL::Compara::AlignSlice::Slice') {
    return $obj->stable_id."::".JSON->new->encode($args->{'__orig_slice'});
  }

  return $obj->dbID || $obj->stable_id;
}

sub _get_regular_exons {
  my ($self,$args,$t) = @_;

  my @eff;
  my $t_coding_start = $t->coding_region_start // -1e6;
  my $t_coding_end = $t->coding_region_end // -1e6;
  foreach my $e (sort { $a->start <=> $b->start } @{$t->get_all_Exons}) {
    next unless defined $e;
    my $ef = {
      _unique => $self->_unique($args,$e),
      start => $e->start,
      end => $e->end,
      strand => $e->strand,
    };
    my $coding_start = max($t_coding_start,$e->start);
    my $coding_end = min($t_coding_end,$e->end);
    if($coding_start <= $coding_end) {
      $ef->{'coding_start'} = $coding_start - $e->start;
      $ef->{'coding_end'} = $e->end - $coding_end;
    }
    push @eff,$ef;
  }
  return \@eff;
}

sub _get_alignslice_exons {
  my ($self,$args,$t) = @_;

  my @exons = @{$t->get_all_Exons};
  my @eff;
  my $t_coding_start = $t->coding_region_start // -1e6;
  my $t_coding_end = $t->coding_region_end // -1e6;
  foreach my $e (sort { ($a->start||0) <=> ($b->start||0) } @exons) {
    my $ef = {
      _unique => $self->_unique($args,$e),
      start => $e->start||0,
      end => $e->end||0,
      strand => $e->strand,
    };
    my $coding_start = max($t_coding_start,$ef->{'start'});
    my $coding_end = min($t_coding_end,$ef->{'end'});
    if($coding_start <= $coding_end) {
      $ef->{'coding_start'} = $coding_start - $ef->{'start'};
      $ef->{'coding_end'} = $ef->{'end'} - $coding_end;
    }
    push @eff,$ef;
  }
  return \@eff;
}

sub _get_exons {
  my ($self,$args,$t) = @_;

  if(ref($args->{'slice'}) eq 'Bio::EnsEMBL::Compara::AlignSlice::Slice') {
    return $self->_get_alignslice_exons($args,$t);
  } else {
    return $self->_get_regular_exons($args,$t);
  }
}

sub _title {
  my ($self,$t,$g) = @_; 
  
  my $title = 'Transcript: ' . $t->stable_id;
  $title .= '; Gene: ' . $g->stable_id if $g->stable_id;
  $title .= '; Location: ' . $t->seq_region_name . ':' . $t->seq_region_start . '-' . $t->seq_region_end;
  
  return $title
}

sub _get_transcripts {
  my ($self,$args,$g) = @_;

  my @tff;
  my @trans = sort { $b->start <=> $a->start } @{$g->get_all_Transcripts};
  @trans = reverse @trans if $g->strand; 
  foreach my $t (@trans) {
    if($args->{'only_attrib'}) {
      next unless @{$t->get_all_Attributes($args->{'only_attrib'})};
    }
    my $tf = {
      _unique => $self->_unique($args,$t),
      start => $t->start,
      end => $t->end,
      strand => $g->strand,
      colour_key => $self->_colour_key($args,$g,$t),
      href => $self->_href($args,$g,$t),
      label => $self->_feature_label($args,$g,$t),
      title => $self->_title($t,$g),
      exons => $self->_get_exons($args,$t),
      stable_id => $t->stable_id,
      coding => !!$t->translation,
      ccds => scalar @{$t->get_all_Attributes('ccds')||[]},
    };
    if($t->translation) {
      $tf->{'translation_stable_id'} = $t->translation->stable_id;
    }
    push @tff,$tf;
  }
  return \@tff;
}

sub _is_coding_gene {
  my ($self, $gene) = @_;

  foreach (@{$gene->get_all_Transcripts}) {
    return 1 if $_->translation;
  }

  return 0;
}

sub get {
  my ($self,$args) = @_;
  my (@out,$genes);
  if($args->{'prediction'}) {
    $genes = $self->_get_prediction_transcripts($args);
  } else {
    $genes = $self->_get_genes($args);
  }
  foreach my $g (@$genes) {
    my $title = sprintf("Gene: %s; Location: %s:%s-%s",
                        $g->stable_id,$g->seq_region_name,
                        $g->seq_region_start,$g->seq_region_end);
    $title = $g->external_name.'; ' if $g->external_name;

    my $gf = {
      _unique => $self->_unique($args,$g),
      start => $g->start,
      end => $g->end,
      href => $self->_href($args,$g),
      title => $title,
      label => $self->_feature_label($args,$g),
      colour_key => $self->_colour_key($args,$g),
      strand => $g->strand,
      stable_id => $g->stable_id,
      transcripts => $self->_get_transcripts($args,$g),
      coding => $self->_is_coding_gene($g),
    };
    push @out,$gf;
  }
  return \@out;
}

1;
