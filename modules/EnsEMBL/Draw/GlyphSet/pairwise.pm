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

package EnsEMBL::Draw::GlyphSet::pairwise;

### Module for drawing data in WashU's tabix-indexed pairwise format

use strict;
use warnings;
no warnings 'uninitialized';

use List::Util qw(min max);

use Bio::EnsEMBL::IO::Adaptor::PairwiseAdaptor;

use EnsEMBL::Draw::Utils::PairedFeature;
use EnsEMBL::Web::File::AttachedFormat::PAIRWISE;
use EnsEMBL::Web::File::Utils::URL;

use base qw(EnsEMBL::Draw::GlyphSet::_alignment);

sub my_helplink   { return 'pairwise'; }
sub feature_id    { $_[1]->id;       }
sub feature_group { $_[1]->id;       }
sub feature_label { $_[1]->id;       }
sub feature_title { return undef;    }
sub href          { return $_[0]->_url({ action => 'UserData', id => $_[1]->id, %{$_[2]||{}} }); }
sub href_bgd      { return $_[0]->_url({ action => 'UserData' }); }

sub pairwise_adaptor {
  my ($self,$in) = @_;

  $self->{'_cache'}->{'_pairwise_adaptor'} = $in if defined $in;
 
  my $error;
  unless ($self->{'_cache'}->{'_pairwise_adaptor'}) { 
    my $url = $self->my_config('url');
    if ($url && $url =~ /^(http|ftp)/) { ## Actually a URL, not a local file
      ## Check file is available before trying to load it 
      ## (Bio::DB::BigFile does not catch C exceptions)
      my $headers = EnsEMBL::Web::File::Utils::URL::get_headers($self->my_config('url'), {
                                                                    'hub' => $self->{'config'}->hub, 
                                                                    'no_exception' => 1
                                                            });
      if ($headers) {
        if ($headers->{'Content-Type'} !~ 'text/html') { ## Not being redirected to a webpage, so chance it!
          my $ad = Bio::EnsEMBL::IO::Adaptor::PairwiseAdaptor->new($self->my_config('url'));
          #$error = "Broken pairwise file" unless $ad->check;
          $self->{'_cache'}->{'_pairwise_adaptor'} = $ad;
        }
        else {
          $error = "File at URL ".$self->my_config('url')." does not appear to be of type Pairwise; returned MIME type ".$headers->{'Content-Type'};
        }
      }
      else {
        $error = "No HTTP headers returned by URL ".$self->my_config('url');
      }
    } 
    else {
      my $ad = Bio::EnsEMBL::IO::Adaptor::PairwiseAdaptor->new($self->my_config('url'));
      #$error = "Broken pairwise file" unless $ad->check;
      $self->{'_cache'}->{'_pairwise_adaptor'} = $ad;
    }
  }
  $self->errorTrack("Could not retrieve file") if $error;
  return $self->{'_cache'}->{'_pairwise_adaptor'};
}

sub format {
  my $self = shift;

  my $format = $self->{'_cache'}->{'format'} ||=
    EnsEMBL::Web::File::AttachedFormat::PAIRWISE->new(
      $self->{'config'}->hub,
      "PAIRWISE",
      $self->my_config('url'),
      $self->my_config('style'), # contains trackline
    );
  $format->_pairwise_adaptor($self->pairwise_adaptor);
  return $format;
}

sub features {
  my ($self, $options) = @_;
  my %config_in = map { $_ => $self->my_config($_) } qw(colouredscore style);
  
  $options = { %config_in, %{$options || {}} };

  my $pwa       = $options->{'adaptor'} || $self->pairwise_adaptor;
  return [] unless $pwa;
  my $format    = $self->format;
  my $slice     = $self->{'container'};
  my $features  = $pwa->fetch_features($slice->seq_region_name, $slice->start, $slice->end + 1);
  my $config    = {};
  my $max_score = 0;
  my $key       = $self->my_config('description') =~ /external webserver/ ? 'url' : 'feature';
  
  $self->{'_default_colour'} = $self->SUPER::my_colour($self->my_config('sub_type'));
  
  ## Convert raw hashes into basic objects 
  my $feature_objects;
  foreach (@$features) {
    my $f = EnsEMBL::Draw::Utils::PairedFeature->new($_);
    $_->map($slice);
    $max_score = max($max_score, $_->score);
    push @$feature_objects, $_;
  }
  
  return ($key => [ $feature_objects, { %$config, %{$format->parse_trackline($format->trackline)} } ]);
}
 
sub my_colour {
  my ($self, $k, $v) = @_;
  my $c = $self->{'parser'}{'tracks'}{$self->{'track_key'}}{'config'}{'color'} || $self->{'_default_colour'};
  return $v eq 'join' ?  $self->{'config'}->colourmap->mix($c, 'white', 0.8) : $c;
}

1;

