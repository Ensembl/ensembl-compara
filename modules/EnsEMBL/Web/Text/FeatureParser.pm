package EnsEMBL::Web::Text::FeatureParser;

=head1 NAME

EnsEMBL::Web::Text::FeatureParser;

=head1 SYNOPSIS

This object parses data supplied by the user and identifies sequence locations for use by other Ensembl objects

=head1 DESCRIPTION

  my $parser = EnsEMBL::Web::Text::FeatureParser->new();
    
      $parser->parse($data);

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

=cut

use strict;
use warnings;
no warnings "uninitialized";
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Response;
use Data::Dumper;

use EnsEMBL::Web::Text::FeatureParser::BED;
use EnsEMBL::Web::Text::FeatureParser::GFF;
use EnsEMBL::Web::Text::FeatureParser::GTF;
use EnsEMBL::Web::Text::FeatureParser::PSL;
use EnsEMBL::Web::Text::FeatureParser::DAS;
use EnsEMBL::Web::Text::FeatureParser::WIG;
use EnsEMBL::Web::Text::FeatureParser::GBrowse;
use EnsEMBL::Web::Text::Feature::generic;
use EnsEMBL::Web::SpeciesDefs;
use EnsEMBL::Web::CompressionSupport;


#----------------------------------------------------------------------

=head2 new

  Arg [1]   : Ensembl Object 
  Function  : creates a new FeatureParser object
  Returntype: EnsEMBL::Web::Text::FeatureParser
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub new {
  my $class = shift;
  my $data = {
  'filter' => {},
  'URLs'       => [],
  'browser_switches' => {},
  'tracks'       => {},
  '_current_key'   => 'default',
  };
  bless $data, $class;
  return $data;
}

sub species_defs {
  my $self = shift;
  return $self->{'_species_defs'} ||= EnsEMBL::Web::SpeciesDefs->new(); 
}

#----------------------------------------------------------------------

=head2 current_key

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub current_key {
  my $self = shift;
  $self->{'_current_key'} = shift if @_;
  return $self->{'_current_key'};
}


#----------------------------------------------------------------------

=head2 format

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub format {
  my $self = shift;
  $self->{_info}{format} = shift if @_;
  return $self->{'_info'}->{'format'};
}

sub get_format {
  my $self = shift;
  return $self->{'_info'}->{'format'};
}

#----------------------------------------------------------------------

=head2 set_filter

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub set_filter {
  my $self = shift;
  $self->{'filter'} = {
     'chr'  => $_[0] eq 'ALL' ? undef : $_[0],
     'start'  => $_[1],
     'end'  => $_[2],
  }
}


#----------------------------------------------------------------------

=head2 analyse

  Arg [1]   :  
  Function  : Analyses a data string (e.g. from a form input), with the intention of identifying file format and other contents
  Returntype: hash reference 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub analyse {
  my ($self, $data) = @_;
  return unless $data;
  my %info;
  foreach my $row ( split /\n/, $data ) {
    my @analysis = $self->analyse_row($row);
    if( $analysis[2] ) {
      $info{$analysis[0]}{$analysis[1]} = $analysis[2];
    } else {
      $info{$analysis[0]} = $analysis[1];
    }
  ## Should we halt the analysis once we have a file format? Will any other useful info appear later in the file?
    last if $analysis[0] eq 'format';
  }

  $self->format($info{'format'});
  return \%info;
}

#----------------------------------------------------------------------

=head2 analyse_row

  Arg [1]   :  
  Function  : Parses an individual row of data, i.e. a single feature
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub analyse_row {
  my( $self, $row ) = @_;
  chomp;
  $row =~ s/[\t\r\s]+$//g;
  
  if( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
    return ('browser_switches', $1, $2);
  } elsif ($row =~ s/^track\s+(.*)$/$1/i) {
    my %config;
    while( $row ne '' ) {
      if( $row =~ s/^(\w+)\s*=\s*\"([^\"]+)\"// ) {  
        my $key   = $1;
        my $value = $2;
        while( $value =~ s/\\$// && $row ne '') {
          if( $row =~ s/^([^\"]+)\"\s*// ) {
            $value .= "\"$1";
          } else {
            $value .= "\"$row"; 
            $row = '';
          }
        }
        $row =~ s/^\s*//;
        $config{$key} = $value;
      } 
      elsif( $row =~ s/(\w+)\s*=\s*(\S+)\s*// ) {
        $config{$1} = $2;
      } 
      else {
        $row ='';
      }
    }
    if (my $ttype = $config{type}) {
      return ('format', 'WIG') if ($ttype =~ /wiggle_0/i);
    }
  } else {
    return unless $row =~ /\d+/g ;
    if( $row =~ /^reference(\s+)?=(\s+)?(.+)/ ) {
      return ('format', 'GBrowse');
    }   
    my @tab_del = split /(\t|  +)/, $row;

    my $current_key = $self->{'_current_key'} ;
    if( $tab_del[12] eq '.' || $tab_del[12] eq '+' || $tab_del[12] eq '-' ) {
      if( $tab_del[16] =~ /^(gene_id|transcript_id) [^;]+(\; (gene_id|transcript_id) [^;]+)?/ ) { ## GTF format
        return ('format', 'GTF');   
      } else {     ## GFF format
        return ('format', 'GFF');   
      }
    } elsif ( $tab_del[14] eq '+' || $tab_del[14] eq '-' || $tab_del[14] eq '.') { # DAS format accepted by Ensembl
      return ('format', 'DAS');   
    } else {
      my @ws_delim = split /\s+/, $row;
      if( $ws_delim[8] =~/^[-+][-+]?$/  ) { ## PSL format
        return ('format', 'PSL');   
      } elsif ($ws_delim[0] =~/^>/ ) {  ## Simple format (chr/start/end/type
        return ('format', 'generic');   
      } else { 
        my $fcount = scalar(@ws_delim);
        if ($fcount > 2 and $fcount < 13) {
          if ($ws_delim[1] =~ /\d+/ && $ws_delim[2] =~ /\d+/) {
            return ('format', 'BED');   
          }
        }
      }
    } 
  }
}
 
#----------------------------------------------------------------------

=head2 parse

  Arg [1]   :  
  Function  : Parses a data string (e.g. from a form input)
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub parse {
  my ($self, $data, $format) = @_;
  return unless $data;
  foreach my $row ( split /\n/, $data ) {
    $self->parse_row($row, $format);
  }

}

sub parse_old {
  my ($self, $data, $format) = @_;
  return unless $data;
  if (!$format) {
    my $info = $self->analyse($data);
    $format = $info->{'format'};
  }
  foreach my $row ( split /\n/, $data ) {
   $self->parse_row($row, $format);
  }
}

#----------------------------------------------------------------------

=head2 parse_file

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub parse_file {
  my( $self, $file, $format ) = @_;
  return unless $file;

  if( !$format ) {
    while( <$file> ) {
      my @analysis = $self->analyse_row( $_ );
      if( $analysis[0] eq 'format') {
        $format = $analysis[1];
        last;
      }
    }   
  }

  while( <$file> ) {
    $self->parse_row( $_, $format );
  }   
}

#----------------------------------------------------------------------

=head2 parse_URL

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub parse_URL {
  my( $self, $url, $format ) = @_;
  my $useragent = LWP::UserAgent->new();  
  $useragent->proxy( 'http', $self->species_defs->ENSEMBL_WWW_PROXY ) if( $self->species_defs->ENSEMBL_WWW_PROXY );   
  foreach my $URL ( $url ) {  
    my $request = new HTTP::Request( 'GET', $URL );
    $request->header( 'Pragma'       => 'no-cache' );
    $request->header( 'Cache-control' => 'no-cache' );
    my $response = $useragent->request($request); 
    if( $response->is_success ) {
      my $content = $response->content;
      EnsEMBL::Web::CompressionSupport::uncomp( \$content ); 
      if (!$format) {
        my $info = $self->analyse( $content );
        $format = $info->{'format'};
      }
      $self->parse( $content, $format );
    } else {
       warn( "Failed to parse: $URL" );
    }
  }   
}

#----------------------------------------------------------------------

=head2 parse_row

  Arg [1]   :  
  Function  : Parses an individual row of data, i.e. a single feature
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub parse_row {
  my( $self, $row, $format ) = @_;
  return if ($row =~ /^\#/);
  $row =~ s/[\t\r\s]+$//g;


  if( $row =~ /^browser\s+(\w+)\s+(.*)/i ) {
    $self->{'browser_switches'}{$1}=$2;   
  } elsif ($row =~ s/^track\s+(.*)$/$1/i) {
    my %config;
    while( $row ne '' ) {
      if( $row =~ s/^(\w+)\s*=\s*"([^"]+)"// ) {  
        my $key   = $1;
        my $value = $2;
        while( $value =~ s/\\$// && $row ne '') {
          if( $row =~ s/^([^"]+)"\s*// ) {
            $value .= "\"$1";
          } else {
            $value .= "\"$row"; 
            $row = '';
          }
        }
        $row =~ s/^\s*//;
        $config{$key} = $value;
      } elsif( $row =~ s/(\w+)\s*=\s*(\S+)\s*// ) {
        $config{$1} = $2;
      } else {
        $row ='';
      }
    }
 
    $config{'name'} ||= 'default';
    my $current_key = $config{'name'};# || 'default';
    $self->{'tracks'}{ $current_key } ||= { 'features' => [], 'config' => \%config };
    $self->{'_current_key'} = $current_key;
  } else {
    return unless $row =~ /\d+/g ;
    my @tab_del = split /(\t|  +)/, $row;
    my $current_key = $self->{'_current_key'} ;
    if( $format =~ /^G[TF]F/ ) { ## Hack can't distinguish GFF from GTF cleanly
      $self->store_feature( $current_key, EnsEMBL::Web::Text::Feature::GFF->new( \@tab_del ) ) 
        if $self->filter($tab_del[0],$tab_del[6],$tab_del[8]);
#    } 
#  elsif ($format eq 'GTF')  { 
#    $self->store_feature( $current_key, EnsEMBL::Web::Text::Feature::GTF->new( \@tab_del ) ) 
#    if $self->filter($tab_del[0],$tab_del[6],$tab_del[8]);
    } elsif( $format eq 'DAS' ) { 
#      $current_key = $tab_del[2] if $current_key eq 'default';
      $self->store_feature( $current_key, EnsEMBL::Web::Text::Feature::DAS->new( \@tab_del ) ) 
        if $self->filter($tab_del[8],$tab_del[10],$tab_del[12]);
    } else {
      my @ws_delim = split /\s+/, $row; 
      if( $format eq 'PSL' ) {
        $self->store_feature( $current_key, EnsEMBL::Web::Text::Feature::PSL->new( \@ws_delim ) ) 
          if $self->filter($ws_delim[13],$ws_delim[15],$ws_delim[16]);
      } elsif( $format eq 'BED' ) {
#        $current_key = $ws_delim[3] if $current_key eq 'default';
        $self->store_feature( $current_key, EnsEMBL::Web::Text::Feature::BED->new( \@ws_delim ) )
          if $self->filter($ws_delim[0],$ws_delim[1],$ws_delim[2]);
      } else {
        $self->store_feature( $ws_delim[4], EnsEMBL::Web::Text::Feature::generic->new( \@ws_delim ) ) 
          if $self->filter($ws_delim[1],$ws_delim[2],$ws_delim[3]);
      } 
    } 
  }
}

#----------------------------------------------------------------------

=head2 

  Arg [1]   :  
  Function  : stores a feature in the parser object
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub store_feature {
  my ( $self, $key, $feature ) = @_;
  push @{$self->{'tracks'}{$key}{'features'}}, $feature;
}

#----------------------------------------------------------------------

=head2 

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub get_all_tracks{$_[0]->{'tracks'}}

#----------------------------------------------------------------------

=head2 

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub fetch_features_by_tracktype{
  my ( $self, $type ) = @_;
  return $self->{'tracks'}{ $type }{'features'} ;
}

#----------------------------------------------------------------------

=head2 

  Arg [1]   :  
  Function  : 
  Returntype: 
  Exceptions: 
  Caller  : 
  Example   : 

=cut

sub filter {
  my ( $self, $chr, $start, $end) = @_;
  return ( ! $self->{'filter'}{'chr'}   || $chr eq 'chr'.$self->{'filter'}{'chr'} 
        || $chr eq $self->{'filter'}{'chr'}   ) &&
     ( ! $self->{'filter'}{'end'}   || $start <= $self->{'filter'}{'end'}   ) &&
     ( ! $self->{'filter'}{'start'} || $end   >= $self->{'filter'}{'start'} )  ;
}

sub _check_data_row {
  my $self = shift;
  my @formatCheck = $self->my_spec;

  my @fields = ();
  for (my $i=0; $i<$#fields; $i++) {
    my $check = $formatCheck[$i] or return 'Unexpected field';
    my $regexp = $check->{'regexp'} or next; # Field can contain anything
    if ($fields[$i] =~ /$regexp/) {
      $formatCheck[$i]->{check_fail} = 0;
    } else {
      return 'Illegal field entry';
    }
  }
  
  foreach my $f (@formatCheck) {
    return 'Missing required field' if ($f->{'check_fail'});
  }
  
  return;
}

sub init {
  my ($self, $data) = @_;
  return unless $data;

  my %info;
  my $has_data = 0;
  foreach my $row ( split '\n', $data ) {
    next unless $row;
    $has_data++;
    my @analysis = $self->analyse_row($row);
    if( $analysis[2] ) {
      $info{$analysis[0]}{$analysis[1]} = $analysis[2];
    } else {
      $info{$analysis[0]} = $analysis[1];
    }
    ## Should we halt the analysis once we have a file format? Will any other useful info appear later in the file?
    last if $analysis[0] eq 'format';
    ## Yes it will all to do with what is in the file! but we can leave this for the moment!
  }
  $info{'count'} = $has_data;
  if (my $format = $info{'format'}) {
#     my $p =  __PACKAGE__."::$format";
#     $self = $p->new();
    bless $self, __PACKAGE__."::$format";
  }
  $self->{_info} = \%info;
  return $self;
}


sub init_density {
  ## Hack to make init work with userdata density tracks
  my ($self, $data) = @_;
  return unless $data;

  my %info;
  my $has_data = 0;
  foreach my $row ( split '\n', $data ) {
    next unless $row;
    $has_data++;
    my @analysis = $self->analyse_row($row);
    if( $analysis[2] ) {
      $info{$analysis[0]}{$analysis[1]} = $analysis[2];
    } else {
      $info{$analysis[0]} = $analysis[1];
    }
    ## Should we halt the analysis once we have a file format? Will any other useful info appear later in the file?
    last if $analysis[0] eq 'format';
    ## Yes it will all to do with what is in the file! but we can leave this for the moment!
  }
  $info{'count'} = $has_data;
  $self->{_info} = \%info;
  return $self;
}


1;
