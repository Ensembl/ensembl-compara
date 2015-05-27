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

package EnsEMBL::Web::File::AttachedFormat::BIGBED;

use strict;
use warnings;
no warnings 'uninitialized';

use Bio::EnsEMBL::IO::Adaptor::BigBedAdaptor;

use EnsEMBL::Web::File::Utils::URL qw(chase_redirects);

use base qw(EnsEMBL::Web::File::AttachedFormat);

sub new {
  my $self = shift->SUPER::new(@_);
  return $self;
}

sub _bigbed_adaptor {
  my ($self,$bba) = @_;
  if (defined($bba)) {
    $self->{'_cache'}->{'bigbed_adaptor'} = $bba;
  } elsif (!$self->{'_cache'}->{'bigbed_adaptor'}) {
    $self->{'_cache'}->{'bigbed_adaptor'} = Bio::EnsEMBL::IO::Adaptor::BigBedAdaptor->new($self->{'url'});
  }
  return $self->{'_cache'}->{'bigbed_adaptor'};
}

sub check_data {
  my ($self) = @_;
  my $url = $self->{'url'};
  my $error = '';
  require Bio::DB::BigFile;

  $url = chase_redirects($url, {'hub' => $self->{'hub'}});
  if ($url =~ /^ftp:\/\//i && !$self->{'hub'}->species_defs->ALLOW_FTP_BIGWIG) {
    $error = "The BigBed file could not be added - FTP is not supported, please use HTTP.";
  }
  else {
    # try to open and use the bigbed file
    # this checks that the bigbed files is present and correct
    my $bigbed;
    eval {
      Bio::DB::BigFile->set_udc_defaults;
      $bigbed = Bio::DB::BigFile->bigBedFileOpen($url);
      my $chromosome_list = $bigbed->chromList;
    };
    warn $@ if $@;
    warn "Failed to open BigBed " . $url unless $bigbed;

    if ($@ or !$bigbed) {
      $error = "Unable to open remote BigBed file: $url<br>Ensure that your web/ftp server is accessible to the Ensembl site";
    }
  }
  return ($url, $error);
}

sub style {
  my $self = shift;
  return $self->{'_cache'}->{'style'} ||= $self->_calc_style();
}

sub _calc_style {
  my $self = shift;
  
  my $tl_score = 0;
  my $trackline = $self->{'trackline'};
  if($trackline) {
    $trackline = $self->parse_trackline($trackline) || {};
    $tl_score = $trackline->{'useScore'} || 0;
  }

  # WORK OUT HOW TO CONFIGURE FEATURES FOR RENDERING
  # Explicit: Check if mode is specified on trackline
  if($tl_score == 2) {
    return 'score';
  } elsif($tl_score == 1) {
    return 'colour';
  } elsif($tl_score == 4) {
    return 'wiggle';
  } elsif($tl_score == 0) {
    # Explicit: try autosql
    my $bba = $self->_bigbed_adaptor;
    return 'colour' if defined $bba->has_column('item_colour');
    return 'score'  if defined $bba->has_column('score');
    # Implicit: No help from trackline, have to work it out
    my $line_length = $bba->file_bedline_length;
    if($line_length >= 8) {
      return 'colour';      
    } elsif($line_length >= 5) {
      return 'score';
    } else {
      return 'plain';
    }
  }
}

1;
