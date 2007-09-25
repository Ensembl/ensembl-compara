package EnsEMBL::Web::URLfeatureParser;

use EnsEMBL::Web::URLfeature::WIG;
use EnsEMBL::Web::URLfeature::BED;
use EnsEMBL::Web::URLfeature::PSL;
use EnsEMBL::Web::URLfeature::GFF;
use EnsEMBL::Web::URLfeature::GTF;
use Data::Dumper;
use strict;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;

sub new {
  my $class = shift;
  my $species_defs = shift;
  my $data = {
    'proxy'            => $species_defs->ENSEMBL_WWW_PROXY,
    'URLs'             => [@_],
    'browser_switches' => {},
    'tracks'           => {}
  };
  bless $data, $class;
  return $data;
}

sub parse_URL {
  my $self = shift;
  my $ua = LWP::UserAgent->new();
  $ua->proxy( 'http', $self->{'proxy'} ) if $self->{'proxy'};
  foreach my $URL ( @{$self->{'URLs'}} ) {
    my $request = new HTTP::Request( 'GET', $URL );
    $request->header( 'Pragma' => 'no-cache' );
    $request->header( 'Cache-control' => 'no-cache' );
    my $response = $ua->request($request);
    if( $response->is_success ) {
      $self->parse( $response->content );
    } else {
       warn( "Failed to parse: $URL" );
    }
  } 
}

sub parse {
  my $self = shift;
  my $current_key = 'default';
  my $fcount = 1;
  my $wigConfig;
  foreach my $row ( split /\n/, shift ) {
    next if ($row =~ /^#/);
    $row=~s/[\t\r\s]+$//g;
    if( $row=~/^browser\s+(\w+)\s+(.*)/i ) {
      $self->{'browser_switches'}{$1}=$2;    
    } elsif( $row=~s/^track\s+(.*)$/$1/i ) {
      my %config;
      $wigConfig = {
      	'format' => 'b'
      };
      while( $row ne '' ) {
        if( $row=~s/^(\w+)\s*=\s*"([^"]+)"// ) {
          my $key = $1;
          my $value = $2;
          while( $value=~s/\\$// && $row ne '') {
            if( $row=~s/^([^"]+)"\s*// ) {
              $value.="\"$1";
            } else {
              $value.="\"$row"; 
              $row='';
            }
          }
          $row=~s/^\s*//;
          $config{$key} = $value;
        } elsif( $row=~s/(\w+)\s*=\s*(\S+)\s*// ) {
          $config{$1} = $2;
        } else {
          $row ='';
        }
      }
#  warn "F $current_key : ", scalar(@{$self->{'tracks'}{ $current_key }{'features'}}) if ($current_key ne 'default');; 
      $current_key = $config{'name'} || $current_key;
      $self->{'tracks'}{ $current_key } = { 'features' => [], 'config' => \%config };
    } else {
      if ($self->{'tracks'}{$current_key}->{'config'}{'type'} eq 'wiggle_0') {
        if ($row =~ /variableStep\s+chrom=([^\s]+)(\s+span=)?(\d+)?/i) {
	  $wigConfig->{format} = 'v';
	  $wigConfig->{region} = $1;
	  $wigConfig->{span} = $3 || 1;
	  next;
        } elsif ($row =~ /fixedStep\s+chrom=(.+)\s+start=(\d+)\s+step=(\d+)(\s+span=)?(\d+)?/i) {
	  $wigConfig->{format} = 'f';
	  $wigConfig->{region} = $1;
	  $wigConfig->{span} = $5 || 1;
	  $wigConfig->{start} = $2;
	  $wigConfig->{step} = $3;
	  next;
	}
	
        my @ws_delimited = split /\s+/, $row;
	if ($wigConfig->{format} eq 'v') {
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::WIG->new( [$wigConfig->{'region'}, $ws_delimited[0], $ws_delimited[0] + $wigConfig->{span}, $ws_delimited[1], $fcount++] );
	  
	}elsif ($wigConfig->{format} eq 'f') {
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::WIG->new( [$wigConfig->{'region'}, $wigConfig->{start}, $wigConfig->{start} + $wigConfig->{span}, $ws_delimited[0], $fcount++] );
	  $wigConfig->{start} += $wigConfig->{step};
	} else {
	  push @ws_delimited, $fcount++;
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::WIG->new( \@ws_delimited );
        }
        next;
      }
      
      my @tab_delimited = split /(\t|  +)/, $row;
      if( $tab_delimited[12] eq '.' || $tab_delimited[12] eq '+' || $tab_delimited[12] eq '-' ) {
        if( $tab_delimited[16] =~ /[ ;]/ ) {
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::GTF->new( \@tab_delimited );
        } else {
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::GFF->new( \@tab_delimited );
        }
      } else {
        my @ws_delimited = split /\s+/, $row;
        if( $ws_delimited[8] =~/^[-+][-+]?$/  ) {
          warn "Adding PSL feature";
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::PSL->new( \@ws_delimited );
        } else {
          push @{$self->{'tracks'}{ $current_key }{'features'}}, EnsEMBL::Web::URLfeature::BED->new( \@ws_delimited );
        }
      }
    }
  }
#  warn "F $current_key : ", scalar(@{$self->{'tracks'}{ $current_key }{'features'}}); 
#  warn Dumper(\@{$self->{'tracks'}{ $current_key }{'features'}});
}

1;
