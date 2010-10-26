package EnsEMBL::Web::Text::FeatureParser::WIG;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Text::FeatureParser);

sub parse_row {
  my( $self, $row ) = @_;
  my $columns;

  $row =~ s/^\s+//;
  my @ws_delimited = split /\s+/, $row;
  push @ws_delimited, $ws_delimited[0];

  my $wigConfig = $self->{'tracks'}{ $self->current_key }->{'mode'};

  if ($wigConfig->{format}) {
    if ($wigConfig->{format} eq 'v') {
      $columns = [
                $wigConfig->{'region'}, 
                $ws_delimited[0], 
                $ws_delimited[0] + $wigConfig->{span} - 1, 
                $ws_delimited[1], 
                $ws_delimited[2]
      ];
    } 
    elsif ($wigConfig->{format} eq 'f') {
      $columns = [
                $wigConfig->{'region'}, 
                $wigConfig->{start}, 
                $wigConfig->{start} + $wigConfig->{span} - 1, 
                $ws_delimited[0], 
                $ws_delimited[1]
      ];
      $self->{'tracks'}{ $self->current_key }->{'mode'}->{'start'} += $wigConfig->{step};
    }
	} 
  else {
		$columns = \@ws_delimited;
  }
  return $columns; 
}

sub set_wig_config {
### Set additional parameters needed by WIG display
  my $self = shift;
  my $track = $self->{'tracks'}{ $self->current_key };
  my $config = $track->{'config'};

  my $wig_config = {
		'region'  => $config->{'chrom'},
		'span'    => $config->{'span'} || 1,
  };

  if (defined $config->{'variableStep'}) {
    $wig_config->{'format'} = 'v';
  } 
  elsif (defined $config->{'fixedStep'}) {
    $wig_config->{'format'} = 'f';
	  $wig_config->{'start'}  = $config->{'start'};
	  $wig_config->{'step'}   = $config->{'step'};
	} 
	$track->{'mode'} = $wig_config;
}

1;
