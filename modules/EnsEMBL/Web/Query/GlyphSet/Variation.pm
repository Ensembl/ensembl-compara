package EnsEMBL::Web::Query::GlyphSet::Variation;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 8;

sub fixup {
  my ($self) = @_;

  $self->fixup_config('config');
  $self->fixup_href('href',1);
  $self->fixup_location('start','slice',0);
  $self->fixup_location('end','slice',1);
  $self->fixup_slice('slice','species',20000);
  $self->fixup_location('tag/*/start','slice',0);
  $self->fixup_location('tag/*/end','slice',1);
  $self->fixup_colour('tag/*/colour',undef,undef,'colour_type');
  $self->fixup_colour('tag/*/label_colour','black',['label'],undef,1);
  $self->fixup_href('tag/*/href');
  $self->fixup_label_width('tag/*/label','end');

  # Fix class key (depends on depth)
  if($self->phase eq 'post_process') {
    my $depth = $self->context->depth;
    my $data = $self->data;
    foreach my $f (@$data) {
      $f->{'class'} = 'group' if defined $depth && $depth <= 1;
    }
  }

  $self->SUPER::fixup();
}

sub precache {
  return {
    '1kgindels' => {
      loop => 'genome',
      args => {
        species => 'Homo_sapiens',
        id => 'variation_set_1kg_3',
        config => {
          no_label => 1,
          sets => ['1kg_3'],
          set_name => '1000 Genomes - All - short variants (SNPs and indels)',
        },
        var_db => 'variation',
        config_type => 'contigviewbottom',
        type => 'variation_set_1kg_3',
      }
    },
    'ph-short' => {
      loop => 'genome',
      args => {
        'species' => 'Homo_sapiens',
        'id' => 'variation_set_ph_variants',
        'config' => {
          'no_label' => 1,
          'sets' => ['ph_variants'],
          'set_name' => 'All phenotype-associated - short variants (SNPs and indels)'
        },
        'var_db' => 'variation',
        'config_type' => 'contigviewbottom',
        'type' => 'variation_set_ph_variants',
      }
    }
  };
}

sub colour_key    { return lc $_[1]->display_consequence; }
sub feature_label { my $label = $_[1]->ambig_code; return $label unless $label and $label eq '-'; }

sub href {
  my ($self,$f,$args) = @_;
 
  return {
    species  => $args->{'species'},
    type     => 'Variation',
    v        => $f->variation_name,
    vf       => $f->dbID,
    vdb      => $args->{'var_db'} || 'variation',
    snp_fake => 1,
    config   => $args->{'config_type'},
    track    => $args->{'type'},
  };   
}

sub tag {
  my ($self,$f,$args) = @_;
  my $colour_key = $self->colour_key($f);
  my $label      = $f->ambig_code;
     $label      = '' if $label && $label eq '-';
  my @tags;

  if (($args->{'config'}{'style'}||'') eq 'box') {
    my $style        = $f->start > $f->end ? 'left-snp' : $f->var_class eq 'in-del' ? 'delta' : 'box';
    push @tags, {
      style        => $style,
      colour       => $colour_key,
      letter       => $style eq 'box' ? $label : '',
      start        => $f->start
    };
  } else {
    if (!$args->{'config'}{'no_label'}) {
      my $label = ' ' . $f->variation_name; # Space at the front provides a gap between the feature and the label
      push @tags, {
        style  => 'label',
        label  => $label,
        colour => $colour_key,
        colour_type => ['tag',undef],
        start  => $f->end,
        end    => $f->end + 1,
      };
    }
    if($f->start > $f->end) {
      push @tags, {
        style => 'insertion',
        colour => $colour_key,
        start => $f->start,
        end => $f->end,
        href => $self->href($f,$args)
      };
    }
  }

  return @tags;
}

sub title {
  my ($self,$f,$args) = @_;
  my $vid     = $f->variation_name ||'';
  my $type    = $f->display_consequence || '';
  my $dbid    = $f->dbID || '';
  my ($s, $e) = $self->slice2sr($args->{'slice'},$f->start, $f->end);
  my $loc     = $s == $e ? $s : $s <  $e ? "$s-$e" : "Between $s and $e";

  return "Variation: $vid; Location: $loc; Consequence: $type; Ambiguity code: ". ($f->ambig_code||'');
}

sub _plainify {
  my ($self,$f,$args) = @_;

  return {
    strand => $f->strand,
    start => $f->start,
    end => $f->end,
    colour_key => $self->colour_key($f),
    tag => [$self->tag($f,$args)],
    feature_label => $self->feature_label($f),
    variation_name => $f->variation_name,
    href => $self->href($f),
    title => $self->title($f,$args),
    dbID => $f->dbID, # used in ZMenu, yuk!
  };    
}

sub check_set {
  my ($self, $f, $sets) = @_;

  foreach (@{$f->get_all_VariationSets}) {
    return 1 if $sets->{$_->short_name};
  }

  return 0;
}

sub check_source {
  my ($self, $f, $sources) = @_;
  
  foreach (@{$f->get_all_sources}) { 
    return 1 if $sources->{$_};
  }
  
  return 0;
}

sub fetch_features {
  my ($self,$args) = @_;

  my $adaptors = $self->source('Adaptors');

  my $species = $args->{'species'};
  my $id = $args->{'id'};
  my $filter = $args->{'config'}{'filter'};
  my $source = $args->{'config'}{'source'};
  my $sources = $args->{'config'}{'sources'};
  my $sets = $args->{'config'}{'sets'};
  my $set_name = $args->{'config'}{'set_name'};
  my $var_db = $args->{'var_db'};
  my $slice = $args->{'slice'}; 
 
  my $vdb = $adaptors->variation_db_adaptor($var_db,$species);
  return [] unless $vdb;
  my $orig_failed_flag = $vdb->include_failed_variations;
  $vdb->include_failed_variations(0);
 
  my $snps;
  # different retrieval method for somatic mutations
  if ($id =~ /somatic/) {
    my @somatic_mutations;

    if ($filter) {
      @somatic_mutations = @{$slice->get_all_somatic_VariationFeatures_with_phenotype(undef, undef, $filter, $var_db) || []};
    } elsif ($source) {
      @somatic_mutations = @{$slice->get_all_somatic_VariationFeatures_by_source($source, undef, $var_db) || []};
    } else {
      @somatic_mutations = @{$slice->get_all_somatic_VariationFeatures(undef, undef, undef, $var_db) || []};
    }
    $snps = \@somatic_mutations;
  } else { # get standard variations
    $sources = { map { $_ => 1 } @$sources } if $sources;
    $sets    = { map { $_ => 1 } @$sets } if $sets;
    my %ct      = map { $_->SO_term => $_->rank } values %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES; 
    my @vari_features;
          
    if ($id =~ /set/) {
      my $short_name = ($args->{'config'}{'sets'})->[0];
      my $track_set  = $set_name;
      my $set_object = $vdb->get_VariationSetAdaptor->fetch_by_short_name($short_name);
       
      # Enable the display of failed variations in order to display the failed variation track
      $vdb->include_failed_variations(1) if $track_set =~ /failed/i;
        
      @vari_features = @{$vdb->get_VariationFeatureAdaptor->fetch_all_by_Slice_VariationSet($slice, $set_object) || []};
        
      # Reset the flag for displaying of failed variations to its original state
      $vdb->include_failed_variations($orig_failed_flag);
    } else {
      my @temp_variations = @{$slice->get_all_VariationFeatures(undef, undef, undef, $var_db) || []}; 
      
      ## Add a filtering step here
      # Make "most functional" snps appear first; filter by source/set
      @vari_features =
        map  { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] } 
        grep { $sources ? $self->check_source($_, $sources) : 1 }
        grep { $sets ? $self->check_set($_, $sets) : 1 }
        @temp_variations;
    }   
    $vdb->include_failed_variations($orig_failed_flag);  
    $snps = \@vari_features;
  }

  return $snps||[];
}

sub get {
  my ($self,$args) = @_;

  my $slice = $args->{'slice'};
  my $slice_length = $slice->length;
  my $features_list = $self->fetch_features($args);
  return [map { $self->_plainify($_,$args) } @$features_list];
}

1;
