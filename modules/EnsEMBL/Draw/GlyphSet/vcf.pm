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

package EnsEMBL::Draw::GlyphSet::vcf;

### Module for drawing data in VCF format (either user-attached, or
### internally configured via an ini file or database record

use strict;
no warnings 'uninitialized';

use Role::Tiny;

use Bio::EnsEMBL::IO::Adaptor::VCFAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::Utils::Constants;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub can_json { return 1; }

sub init {
  my $self = shift;

  ## We only need wiggle roles, as alignment rendering has a non-standard name
  Role::Tiny->apply_roles_to_object($self, 'EnsEMBL::Draw::Role::Wiggle');

  ## Cache raw VCF features
  $self->{'features'} = $self->features;
}

############# RENDERING ########################

sub render_histogram {
  my $self = shift;
  return scalar @{$self->features} > 200 ? $self->render_density_bar : $self->render_normal;
}

sub render_normal {
### NB. Takes precendence of method in Role::Wiggle
  my $self = shift;
  if (scalar @{$self->features} > 200) {
    $self->too_many_features;
    return undef;
  }
  else {
    ## Convert raw features into correct data format 
    $self->{'features'} = [{'features' => $self->consensus_features}];
    $self->{'my_config'}->set('drawing_style', ['Feature']);
    $self->draw_features;
  }
}

sub render_density_bar {
  my $self        = shift;
  $self->{'my_config'}->set('height', 20);
  $self->{'my_config'}->set('no_guidelines', 1);
  $self->{'my_config'}->set('integer_score', 1);
  ## Convert raw features into correct data format 
  $self->{'features'} = [{'features' => $self->density_features}];
  $self->render_tiling;
}

############# DATA ACCESS & PROCESSING ########################

sub features {
### Fetch and cache raw features - we'll process them later as needed
  my $self = shift;

  unless ($self->{'features'} && scalar @{$self->{'features'}}) {
    my $slice       = $self->{'container'};
    my $start       = $slice->start;

    my $vcf_adaptor = $self->vcf_adaptor;
    ## Don't assume the adaptor can find and open the file!
    my $consensus   = eval { $vcf_adaptor->fetch_variations($slice->seq_region_name, $slice->start, $slice->end); };
    if ($@) {
      $self->{'features'} = [];
    }
    else {
      $self->{'features'} = $consensus;
    }
  }
  return $self->{'features'};
}

sub consensus_features {
### Turn raw features into consensus features for drawing
### @return Arrayref of hashes
  my $self = shift;
  my $raw_features  = $self->{'features'};
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
    my $unknown_type = 1;
    my $vs           = $f->{'POS'} - $start + 1;
    my $ve           = $vs;

    if (my $sv = $f->{'INFO'}{'SVTYPE'}) {
      $unknown_type = 0;

      if ($sv eq 'DEL') {
        my $svlen = $f->{'INFO'}{'SVLEN'} || 0;
        $ve       = $vs + abs $svlen;

        $f->{'REF'} = substr($f->{'REF'}, 0, 30) . ' ...' if length $f->{'REF'} > 30;
      } 
      elsif ($sv eq 'TDUP') {
        my $svlen = $f->{'INFO'}{'SVLEN'} || 0;
        $ve       = $vs + $svlen + 1;
      } 
      elsif ($sv eq 'INS') {
        $ve = $vs -1;
      }
    } 
    else {
      my ($reflen, $altlen) = (length $f->{'REF'}, length $f->{'ALT'}[0]);

      if ($reflen > 1) {
        $ve = $vs + $reflen - 1;
      } 
      elsif ($altlen > 1) {
        $ve = $vs - 1;
      }
    }

    my $allele_string = join '/', $f->{'REF'}, @{$f->{'ALT'} || []};
    my $vf_name       = $f->{'ID'} eq '.' ? "$f->{'CHROM'}_$f->{'POS'}_$allele_string" : $f->{'ID'};

    if ($slice->strand == -1) {
      my $flip = $slice->length + 1;
      ($vs, $ve) = ($flip - $ve, $flip - $vs);
    }

    ## Set colour by consequence if defined in file
    my $colour  = $colours->{'default'}->{'default'};
    if (defined($f->{'INFO'}->{'VE'})) {
      my $cons = (split /\|/, $f->{'INFO'}->{'VE'})[0];
      if (defined($overlap_cons{$cons})) {
        $colour = $colours->{lc $cons}->{'default'};
      }
    }

    my $fhash = {
                  start   => $vs,
                  end     => $ve,
                  strand  => 1,
                  colour  => $colour,       
                  label   => $vf_name, 
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
  my $vclen    = $slice->length;
  my $im_width = $self->{'config'}->image_width;
  my $divs     = $im_width;
  my $divlen   = $vclen / $divs;
  $divlen      = 10 if $divlen < 10; # Increase the number of points for short sequences
  my $density  = {};
  $density->{int(($_->{'POS'} - $start) / $divlen)}++ for @{$self->features};

  my $colours = $self->species_defs->colour('variation');
  my $colour  = $colours->{'default'}->{'default'};

  my $density_features = [];
  foreach (sort {$density->{$a} <=> $density->{$b}} keys %$density) {
    push @$density_features, {
                              'start'   => $_, 
                              'end'     => $_ + $divlen,
                              'colour'  => $colour,
                              'score'   => $density->{$_}
                              };
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

  return $self->{'_cache'}{'_vcf_adaptor'} ||= Bio::EnsEMBL::IO::Adaptor::VCFAdaptor->new($url);
}

1;
