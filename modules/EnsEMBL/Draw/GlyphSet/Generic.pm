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

package EnsEMBL::Draw::GlyphSet::Generic;

### Parent for new-style glyphsets

use strict;

use Role::Tiny;
use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Draw::GlyphSet);

sub can_json { return 1; }

sub init {
  my $self = shift;
  my @roles;
  ## Always show user tracks, regardless of overall configuration
  $self->{'my_config'}->set('show_empty_track', 1);
  ## We no longer support 'normal' as a renderer key, so force something more useful
  my $display = $self->my_config('display') || $self->my_config('default_display');
  $display = $self->my_config('default_display') if $display eq 'normal';
  my $style = $self->my_config('style') || $display || '';

  if ($style eq 'wiggle' || $style =~ /signal/ || $style eq 'tiling' || $style eq 'gradient') {
    push @roles, 'EnsEMBL::Draw::Role::Wiggle';
    if (exists($self->{'my_config'}{'data'}{'y_min'})) {
      $self->{'my_config'}->set('scaleable', 1);
    }
  }
  else {
    push @roles, 'EnsEMBL::Draw::Role::Alignment';
  }
  push @roles, 'EnsEMBL::Draw::Role::Default';

  ## Apply roles separately, to prevent namespace clashes 
  foreach (@roles) { 
    Role::Tiny->apply_roles_to_object($self, $_);
  }

  $self->{'data'} = $self->get_data;
}

sub render_normal {
## Backwards-compatibility with old drawing code
  my $self = shift;

  ## Different tracks have different opinions of what is 'normal',
  ## so let the configuration decide
  my $renderers = $self->{'my_config'}->get('renderers');
  my $default = $self->{'my_config'}->get('default_display');
  my $default_is_valid = $default ? grep { $_ eq $default } @$renderers : 0;
  unless ($default_is_valid) {
    $default =  $renderers->[2];
  }
  my $method = 'render_'.$default;
  $self->$method;
}

sub get_data {
  my $self = shift;
  warn ">>> IMPORTANT - THIS METHOD MUST BE IMPLEMENTED IN MODULE $self!";
=pod

Because user files can contain multiple datasets, this method should return data 
in the following format:

$data = [
         { #Track1
          'metadata' => {},
          'features' => {
                           '1'  => [{}],
                          '-1'  => [{}],
                        },
          },
          { #Track2
           ... etc...
          },
        ];

The keys of the feature hashref refer to the strand on which we wish to draw the data
(as distinct from the strand on which the feature is actually found, which may be different)
- this should be determined in the file parser, based on settings passed to it

=cut
}

sub no_file {
### Error message when a file is not available
  my ($self, $error)  = @_;
  $error ||= 'File unavailable';

  if ($error =~ /^\d+$/) {
    my %messages = EnsEMBL::Web::Constants::ERROR_MESSAGES;
    my $message = $messages{$error};
    $error = $message->[1];
  }

  $self->errorTrack($error);
}

sub get_strand_filters {
### The strand settings in imageconfig are the reverse of filters,
### so for clarity we need to convert them here
  my ($self, $strand_code) = @_;
  $strand_code ||= $self->{'my_config'}->get('strand');
  my $strand_to_omit  = 0;
  my $skip            = 0;

  if ($strand_code eq 'f') { ## Forward
    ## Don't filter data, but don't draw it on the reverse strand
    $skip = '-1';
  }
  elsif ($strand_code eq 'r') { ## Reverse
    ## Don't filter data, but don't draw it on the forward strand
    $skip = '1';
  }
  elsif ($strand_code eq 'b') { ## Both
    # Don't skip either strand - we want to split the data by strand 
    $strand_to_omit = -$self->strand;
  }

  return ($skip, $strand_to_omit);
}

sub my_empty_label {
  my $self = shift;
  return sprintf('No features from %s in this location on this strand', $self->my_config('name'));
}

1;
