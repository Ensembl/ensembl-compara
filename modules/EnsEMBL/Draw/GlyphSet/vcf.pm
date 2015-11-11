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

use Bio::EnsEMBL::IO::Adaptor::VCFAdaptor;
use Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor;
use Bio::EnsEMBL::Variation::Utils::Constants;

use parent qw(EnsEMBL::Draw::GlyphSet::UserData);

sub can_json { return 1; }

sub init {
  my $self = shift;
  ## Cache raw VCF features
  $self->{'features'} = $self->features;
}

############# RENDERING ########################

sub render_histogram {
  my $self  = shift;
  return scalar @{$self->features} > 200 ? $self->render_density_bar : $self->render_compact;
}

sub render_compact {
  my $self        = shift;
  if (scalar @{$self->features} > 200) {
    $self->too_many_features;
    return undef;
  }
  else {
    ## Convert raw features into consensus features
    $self->{'features'} = $self->consensus_features;
    $self->draw_features;
  }
}

sub render_density_bar {
  my $self        = shift;
  warn ">>> RENDERING DENSITY";
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
  my $self = shift;
  my $raw_features  = $self->{'features'};
  my $config        = $self->{'config'};
  my $slice         = $self->{'container'};
  my $start         = $slice->start;
  my $species       = $self->{'config'}->hub->species;
  my @features;

  # If we have a variation db attached we can try and find a known SNP mapped at the same position
  # But at the moment we do not display this info so we might as well just use the faster method 
  #     my $vfa = $slice->_get_VariationFeatureAdaptor()->{list}->[0];
   
  my $vfa = Bio::EnsEMBL::Variation::DBSQL::VariationFeatureAdaptor->new_fake($species);
  my %overlap_cons = %Bio::EnsEMBL::Variation::Utils::Constants::OVERLAP_CONSEQUENCES;
  my $colours = $self->species_defs->colour('variation');
   
  foreach my $a (@$raw_features) {
    warn ">>> SNP $a";
    my $unknown_type = 1;
    my $vs           = $a->{'POS'} - $start + 1;
    my $ve           = $vs;
    my $info;
    $info .= ";  $_: $a->{'INFO'}{$_}" for sort keys %{$a->{'INFO'} || {}};

    if (my $sv = $a->{'INFO'}{'SVTYPE'}) {
      $unknown_type = 0;

      if ($sv eq 'DEL') {
        my $svlen = $a->{'INFO'}{'SVLEN'} || 0;
        $ve       = $vs + abs $svlen;

        $a->{'REF'} = substr($a->{'REF'}, 0, 30) . ' ...' if length $a->{'REF'} > 30;
      } 
      elsif ($sv eq 'TDUP') {
        my $svlen = $a->{'INFO'}{'SVLEN'} || 0;
        $ve       = $vs + $svlen + 1;
      } 
      elsif ($sv eq 'INS') {
        $ve = $vs -1;
      }
    } 
    else {
      my ($reflen, $altlen) = (length $a->{'REF'}, length $a->{'ALT'}[0]);

      if ($reflen > 1) {
        $ve = $vs + $reflen - 1;
      } 
      elsif ($altlen > 1) {
        $ve = $vs - 1;
      }
    }

    my $allele_string = join '/', $a->{'REF'}, @{$a->{'ALT'} || []};
    my $vf_name       = $a->{'ID'} eq '.' ? "$a->{'CHROM'}_$a->{'POS'}_$allele_string" : $a->{'ID'};

    if ($slice->strand == -1) {
      my $flip = $slice->length + 1;
      ($vs, $ve) = ($flip - $ve, $flip - $vs);
    }

    ## Set colour by consequence if defined in file
    my $colour  = $colours->{'default'}->{'default'};
    if (defined($a->{'INFO'}->{'VE'})) {
      my $cons = (split /\|/, $a->{'INFO'}->{'VE'})[0];
      if (defined($overlap_cons{$cons})) {
        $colour = $colours->{lc $cons}->{'default'};
      }
    }

    my $snp = {
      start   => $vs,
      end     => $ve,
      strand  => 1,
      colour  => $colour,        
    };

    push @features, $snp;
  }
  return @features;
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
