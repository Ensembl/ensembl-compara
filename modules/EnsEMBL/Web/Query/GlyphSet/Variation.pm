=head1 LICENSE

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

package EnsEMBL::Web::Query::GlyphSet::Variation;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Query::Generic::GlyphSet);

our $VERSION = 12;

sub fixup {
  my ($self) = @_;

  $self->fixup_config('config');
  $self->fixup_href('href',1);
  $self->fixup_location('start','slice',0);
  $self->fixup_location('end','slice',1);
  $self->fixup_slice('slice','species',20000);

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
      loop => ['genome'],
      args => {
        species => 'Homo_sapiens',
        id => 'variation_set_1kg_3',
        config => {
          sets => ['1kg_3'],
          set_name => '1000 Genomes - All - short variants (SNPs and indels)',
        },
        var_db => 'variation',
        config_type => 'contigviewbottom',
        type => 'variation_set_1kg_3',
      }
    },
    'variation-mouse' => {
      loop => ['genome'],
      args => {
        species => 'Mus_musculus',
        id => 'variation_feature_variation',
        config => {},
        var_db => 'variation',
        config_type => 'contigviewbottom',
        type => 'variation_feature_variation',
      }
    },
    'ph-short' => {
      loop => ['species','genome'],
      args => {
        'id' => 'variation_set_ph_variants',
        'config' => {
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
sub text_overlay  { my $text = $_[1]->ambig_code; return $text unless $text and $text eq '-'; }

sub href {
  my ($self,$f,$args) = @_;

  # Fix URL encoding issue with the "<>" characters
  my $var = $f->variation_name;
  $var =~ s/(<|>)/_/g if $var;

  return {
    species  => $args->{'species'},
    type     => 'Variation',
    v        => $var,
    vf       => $f->dbID,
    vdb      => $args->{'var_db'} || 'variation',
    snp_fake => 1,
    config   => $args->{'config_type'},
    track    => $args->{'type'},
  };   
}

sub type {
  my ($self, $f, $args) = @_;
  my $type;

  if ($f->var_class eq 'insertion' || $f->var_class eq 'deletion') {
    $type = $f->var_class; 
  }

  return $type;
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
    type => $self->type($f,$args),
    label => $f->variation_name,
    text_overlay => $self->text_overlay($f),
    href => $self->href($f,$args),
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
  my $var_db = $args->{'var_db'} || 'variation';
  my $slice = $args->{'slice'};
  my $slice_length = $args->{'slice_length'} || 0;
 
  my $vdb = $adaptors->variation_db_adaptor($var_db,$species);
  return [] unless $vdb;
  my $orig_failed_flag = $vdb->include_failed_variations;
  $vdb->include_failed_variations(0);

  # dont calculate consequences over a certain slice length
  my $no_cons = $slice_length > 1e5 ? 1 : 0;
 
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
      return [] unless $set_object;
       
      # Enable the display of failed variations in order to display the failed variation track
      $vdb->include_failed_variations(1) if $track_set =~ /failed/i;
        
      @vari_features = @{$vdb->get_VariationFeatureAdaptor->fetch_all_by_Slice_VariationSet($slice, $set_object) || []};
        
      # Reset the flag for displaying of failed variations to its original state
      $vdb->include_failed_variations($orig_failed_flag);
    } elsif ($id =~ /^variation_vcf/) {
      my $vca = $vdb->get_VCFCollectionAdaptor;
      my $vcf_id = $id;
      $vcf_id =~ s/^variation_vcf_//;
      if(my $vc = $vca->fetch_by_id($vcf_id)) {
        @vari_features = @{$vc->get_all_VariationFeatures_by_Slice($slice, $no_cons)};
      }
    } else {
      my @temp_variations = @{$vdb->get_VariationFeatureAdaptor->fetch_all_by_Slice_constraint($slice, undef, $no_cons) || []};
      
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
  #warn ">>> FOUND ".scalar @$snps." SNPs";
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
