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

package EnsEMBL::Draw::GlyphSet::vcf;

### Module for drawing data in VCF format (either user-attached, or
### internally configured via an ini file or database record

use strict;
no warnings 'uninitialized';

use List::Util qw(max);

use Role::Tiny::With;
with 'EnsEMBL::Draw::Role::Wiggle';
with 'EnsEMBL::Draw::Role::Default';

use Bio::EnsEMBL::IO::Adaptor::VCFAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::Utils::Constants;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub init {
  my $self = shift;

  ## Cache raw VCF features
  $self->{'data'} = $self->get_data;
}

############# RENDERING ########################

sub render_histogram {
  my $self = shift;
  my $features = $self->get_data->[0]{'features'};
  if ($features) {
    return scalar @$features > 200 ? $self->render_density_bar : $self->render_simple;
  }
  else {
    $self->no_features;
  }
}

sub render_simple {
  my $self = shift;
  my $features = $self->get_data->[0]{'features'};
  if ($features) {
    if (scalar @$features > 200) {
      $self->too_many_features;
      return undef;
    }
    else {
      ## Convert raw features into correct data format 
      $self->{'my_config'}->set('height', 12);
      $self->{'my_config'}->set('show_overlay', 1);
      $self->{'my_config'}->set('default_strand', 1);
      $self->{'my_config'}->set('drawing_style', ['Feature::Variant']);
      $self->{'data'}[0]{'features'} = $self->consensus_features;
      $self->draw_features;
    }
  }
  else {
    $self->no_features;
  }
}

sub render_density_bar {
  my $self        = shift;
  $self->{'my_config'}->set('height', 20);
  $self->{'my_config'}->set('no_guidelines', 1);
  $self->{'my_config'}->set('integer_score', 1);
  my $colours = $self->species_defs->colour('variation');
  $self->{'my_config'}->set('colour', $colours->{'default'}->{'default'});

  ## Convert raw features into correct data format 
  my $density_features = $self->density_features;
  if ($density_features) {
    $self->{'data'}[0]{'features'} = $density_features;
    $self->{'my_config'}->set('max_score', max(@$density_features));
    $self->{'my_config'}->set('drawing_style', ['Graph::Histogram']);
    $self->_render_aggregate;
  }
  else {
    $self->no_features;
  }

}

############# DATA ACCESS & PROCESSING ########################

sub get_data {
### Fetch and cache raw features - we'll process them later as needed
  my $self = shift;
  $self->{'my_config'}->set('show_subtitle', 1);
  $self->{'data'} ||= [];

  unless (scalar @{$self->{'data'}}) {
    my $slice       = $self->{'container'};
    my $start       = $slice->start;

    ## Allow for seq region synonyms
    my $seq_region_names = [$slice->seq_region_name];
    if ($self->{'config'}->hub->species_defs->USE_SEQREGION_SYNONYMS) {
      push @$seq_region_names, map {$_->name} @{ $slice->get_all_synonyms };
    }

    my $vcf_adaptor = $self->vcf_adaptor;
    my $consensus;
    foreach my $seq_region_name (@$seq_region_names) {
      $consensus = eval { $self->vcf_adaptor->fetch_variations($seq_region_name, $slice->start, $slice->end); };
      warn $@ if $@;
      return [] if $@;
      last if $consensus and @$consensus;
    } 

    my $colours = $self->species_defs->colour('variation');
    my $colour  = $colours->{'default'}->{'default'}; 
      
    $self->{'data'} = [{'metadata' => {
                                        'name'    => $self->{'my_config'}->get('name'),
                                        'colour'  => $colour,
                                       }, 
                        'features' => $consensus
                            }];
  }
  return $self->{'data'};
}

sub consensus_features {
### Turn raw features into consensus features for drawing
### @return Arrayref of hashes
  my $self = shift;
  my $raw_features  = $self->{'data'}[0]{'features'};
  my $config        = $self->{'config'};
  my $slice         = $self->{'container'};
  my $start         = $slice->start;
  my $species       = $self->{'config'}->hub->species;
  my $features      = [];

  # If we have a variation db attached we can try and find a known SNP mapped at the same position
  # But at the moment we do not display this info so we might as well just use the faster method 
  #     my $vfa = $slice->_get_VariationFeatureAdaptor()->{list}->[0];
   
  my $vfa = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
  my %overlap_cons = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $colours = $self->species_defs->colour('variation');
   
  foreach my $f (@$raw_features) {
    my $type         = undef;
    my $unknown_type = 1;
    my $vs           = $f->{'POS'} - $start + 1;
    my $ve           = $vs;
    my $sv           = $f->{'INFO'}{'SVTYPE'};
    my $info_string;
    $info_string .= ";  $_: $a->{'INFO'}{$_}" for sort keys %{$a->{'INFO'} || {}};

    ## N.B. Compensate for VCF indel start including the bp before the variant
    if ($sv) {
      $unknown_type = 0;

      if ($sv eq 'DEL') {
        $type = 'deletion';
        my $svlen = $f->{'INFO'}{'SVLEN'} || 0;
        $vs++;
        $ve       = $vs + abs $svlen;

        $f->{'REF'} = substr($f->{'REF'}, 0, 30) . ' ...' if length $f->{'REF'} > 30;
      } 
      elsif ($sv eq 'TDUP') {
        my $svlen = $f->{'INFO'}{'SVLEN'} || 0;
        $ve       = $vs + $svlen + 1;
      } 
      elsif ($sv eq 'INS') {
        $type = 'insertion';
        $vs++;
        $ve = $vs -1;
      }
    } 
    else {
      my ($reflen, $altlen) = (length $f->{'REF'}, length $f->{'ALT'}[0]);

      if ($altlen > $reflen) {
        $vs++;
        $type = 'insertion';
      }
      elsif ($altlen < $reflen) {
        $vs++;
        $type = 'deletion';
      }

      if ($reflen > 1) {
        $ve = $vs + $reflen - 1;
      } 
      elsif ($altlen > 1) {
        $ve = $vs - 1;
      }
      $sv = 'OTHER';
    }

    my $allele_string = join '/', $f->{'REF'}, @{$f->{'ALT'} || []};
    my $vf_name       = $f->{'ID'} eq '.' ? "$f->{'CHROM'}_$f->{'POS'}_$allele_string" : $f->{'ID'};

    ## Flip for drawing
    if ($slice->strand == -1) {
      my $flip = $slice->length + 1;
      ($vs, $ve) = ($flip - $ve, $flip - $vs);
    }

    ## Zmenu
    my %lookup = (
                  'INS'   => 'Insertion',
                  'DEL'   => 'Deletion',
                  'TDUP'  => 'Duplication',
                  );
    my $location = sprintf('%s:%s', $slice->seq_region_name, $vs + $slice->start - 1);
    $location   .= '-'.($ve + $slice->start - 2) if ($ve && $ve != $vs);

    my $title = "$vf_name; Location: $location; Allele: $allele_string";
    $title .= 'Type: '.$lookup{$sv}.'; ' if $lookup{$sv};
    if (keys %{$f->{'INFO'}||{}}) {
      $title .= '; INFO: --------------------------';
      foreach (sort keys %{$f->{'INFO'}}) {
        $title .= sprintf('; %s: %s', $_, $f->{'INFO'}{$_} || '');
      }
    }

    my $colour  = $colours->{'default'}->{'default'};

    ## Get consequence type
    my ($consequence, $ambig_code);
    if (defined($f->{'INFO'}->{'VE'})) {
      $consequence = (split /\|/, $f->{'INFO'}->{'VE'})[0];
    }
    else {
      ## Not defined in file, so look up in database
      my $snp = {
        start            => $vs, 
        end              => $ve, 
        strand           => 1, 
        slice            => $slice,
        allele_string    => $allele_string,
        variation_name   => $vf_name,
        map_weight       => 1, 
        adaptor          => $vfa, 
        seqname          => $info_string ? "; INFO: --------------------------$info_string" : '',
        consequence_type => $unknown_type ? ['INTERGENIC'] : ['COMPLEX_INDEL']
      };
      bless $snp, 'Bio::EnsEMBL::Variation::VariationFeature';

      $snp->get_all_TranscriptVariations;

      $consequence = $snp->display_consequence;
      $ambig_code  = $snp->ambig_code;
    }
      
    ## Set colour by consequence
    if ($consequence && defined($overlap_cons{$consequence})) {
      $colour = $colours->{lc $consequence}->{'default'};
    }

    my $fhash = {
                  start         => $vs,
                  end           => $ve,
                  strand        => 1,
                  colour        => $colour,       
                  label         => $vf_name, 
                  text_overlay  => $ambig_code,
                  title         => $title,
                  type          => $type,
                };

    push @$features, $fhash;
  }
  return $features;
}

sub density_features {
### Merge the features into bins
### @return Arrayref of hashes
  my $self     = shift;
  my $slice    = $self->{'container'};
  my $start    = $slice->start - 1;
  my $length   = $slice->length;
  my $im_width = $self->{'config'}->image_width;
  my $divlen   = $length / $im_width;
  $self->{'data'}[0]{'metadata'}{'unit'} = $divlen;
  ## Prepopulate bins, as histogram requires data at every point
  my %density  = map {$_, 0} (1..$im_width);
  foreach (@{$self->{'data'}[0]{'features'}}) {
    my $key = ($_->{'POS'} - $start) / $divlen;
    $density{int(($_->{'POS'} - $start) / $divlen)}++;
  }

  my $density_features = [];
  foreach (sort {$a <=> $b} keys %density) {
    push @$density_features, $density{$_};
  }
  return $density_features;
}

sub vcf_adaptor {
## get a vcf adaptor
  my $self = shift;
  my $url  = $self->my_config('url');

  if ($url =~ /###CHR###/) {
    my $region = $self->{'container'}->seq_region_name;
       $url    =~ s/###CHR###/$region/g;
  }

  return $self->{'_cache'}{'_vcf_adaptor'} ||= Bio::EnsEMBL::IO::Adaptor::VCFAdaptor->new($url, $self->{'config'}->hub);
}

1;
