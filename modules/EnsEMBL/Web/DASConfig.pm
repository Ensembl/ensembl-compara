package EnsEMBL::Web::DASConfig;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(Bio::EnsEMBL::ExternalData::DAS::Source);

use Time::HiRes qw(time);
use Bio::EnsEMBL::Utils::Exception qw(warning);
use Bio::EnsEMBL::ExternalData::DAS::CoordSystem;
use Bio::EnsEMBL::ExternalData::DAS::SourceParser qw(%GENE_COORDS %PROT_COORDS is_genomic);

# Create a new SourceConfig using a hash reference for parameters.
# Can also use an existing Bio::EnsEMBL::ExternalData::DAS::Source or
# EnsEMBL::Web::DASConfig object.
# Hash should contain:
#   url
#   dsn
#   coords
#   logic_name    (optional, defaults to dsn)
#   label         (optional)
#   caption       (optinal short label)
#   description   (optional)
#   homepage      (optional)
#   maintainer    (optional)
#   on            (views enabled on)
#   category      (menu location)
sub new_from_hashref {
  my ( $class, $hash ) = @_;
  
  $hash->{'coords'} = [ map {
    ref $_ ? Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_hashref($_)
           : Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new_from_string($_)
  } @{$hash->{'coords'}||[]} ];

  # Convert old-style type & assembly parameters to single coords
  if (my $type = $hash->{type}) {
    my $c = $GENE_COORDS{$type} || $PROT_COORDS{$type};
    if ( $c ) {
      push @{ $hash->{coords} }, $c;
    } else {
      $type =~ s/^ensembl_location_//;
      push @{ $hash->{coords} }, Bio::EnsEMBL::ExternalData::DAS::CoordSystem->new(
        -name    => $type,
        -version => $hash->{assembly},
        -species => $ENV{ENSEMBL_SPECIES},
      );
    }
  }
  
  # Create a Bio::EnsEMBL::ExternalData::DAS::Source object to wrap
  # Valid params: url, dsn, coords, logic_name, label, description, homepage, maintainer
  my %params = map { '-'.uc $_ => $hash->{$_} } keys %{ $hash };
  my $self   = $class->SUPER::new( %params );
  
  bless $self, $class;
  
  # Map "old style" view names to the new:
  my %views = ( geneview   => 'Gene/ExternalData',
                protview   => 'Transcript/ExternalData',
                contigview => 'contigviewbottom');
  if ($hash->{enable} || $hash->{on}) {
    $hash->{on} = [ map { $views{$_} || $_ } @{$hash->{on}||[]},@{$hash->{enable}||[]} ] ;
  }
  
  for my $var ( qw( on category caption )  ) {
    if ( exists $hash->{$var} ) {
      $self->$var( $hash->{$var} );
    }
  }
  
  return $self;
}

# DAS sources can be added from URL
# URL will have to be of the following format:
# /geneview?gene=BRCA2&add_das_source=(url=http://das1:9999/das+dsn=mouse_ko_allele+type=markersymbol+name=MySource+active=1)
# other parameters also can be specified, but those are optional ..
#  !!! You have to make sure that the name is unique before calling this function !!!
# TODO: move this code elsewhere?
sub new_from_URL {
  my ( $class, $URL ) = @_;
  $URL =~ s/[\(|\)]//g;                                # remove ( and |
  return unless $URL;
  $URL =~ s/\\ /###/g; # Preserve escaped spaces in source label
  my @das_keys = split(/\s/, $URL);                    # break on spaces...
  my %das_data = map { split (/\=/, $_,2) } @das_keys; # split each entry on =
  
  unless( exists $das_data{url} && exists $das_data{dsn} && (exists $das_data{type} || exists $das_data{coords}) ) {
    warning("DAS source ".$das_data{name}." ($URL) has not been added: Missing parameters");
    next;
  }
  
  # Don't allow external setting of category, ensure default is kept (external)
  delete $das_data{category};
  
  # Expand multi-value parameters
  $das_data{on}     = [split /,/, $das_data{on}];
  $das_data{enable} = [split /,/, $das_data{enable}];
  $das_data{coords} = [split /,/, $das_data{coords}];
  
  # Restore spaces in the label
  if ($das_data{label}) {
    $das_data{label} =~ s/###/ /g ;
  }
  
  # Re-encode link URL
  if ($das_data{linkurl}) {
    $das_data{linkurl} =~ s/\$3F/\?/g;
    $das_data{linkurl} =~ s/\$3A/\:/g;
    $das_data{linkurl} =~ s/\$23/\#/g;
    $das_data{linkurl} =~ s/\$26/\&/g;
  }
  
  push @{$das_data{enable}}, $ENV{'ENSEMBL_SCRIPT'};
  
  # TODO: not sure about these, we're handling coordinate systems differently
  #push @{$das_data{mapping}} , split(/\,/, $das_data{type});
  #$das_data{conftype} = 'external';
  #$das_data{type}     = 'mixed'    if scalar @{$das_data{mapping}} > 1;

  my $self = $class->new_from_hashref(\%das_data);
  return $self;
}

#================================#
#  Web-specific get/set methods  #
#================================#

=head2 on

  Arg [1]    : $views (arrayref)
  Description: get/set for the views the source is available on (arrayref)
  Returntype : arrayref
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub on {
  my $self = shift;
  if ( @_ ) {
    $self->{'on'} = shift;
  }
  return $self->{'on'} && scalar @{$self->{'on'}} ? $self->{'on'} : $self->_guess_views();
}

=head2 is_on

  Arg [1]    : $view (string)
  Description: whether the source is available on the given view
  Returntype : boolean
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub is_on {
  my ( $self, $view ) = @_;
  return grep { $_ eq $view } @{ $self->on || [] }
}

=head2 category

  Arg [1]    : $category (scalar)
  Description: get/set for the data category (menu location) of the source
  Returntype : scalar
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub category {
  my ( $self, $category ) = @_;
  if ( defined $category ) {
    $self->{'category'} = $category;
  }
  return $self->{'category'};
}

=head2 caption

  Arg [1]    : $caption (scalar)
  Description: get/set for the short label (for images) of the source
  Returntype : scalar
  Exceptions : none
  Caller     : general
  Status     : Stable

=cut
sub caption {
  my ( $self, $caption ) = @_;
  if ( defined $caption ) {
    $self->{'caption'} = $caption;
  }
  return $self->{'caption'} || $self->label;
}


sub is_session {
  my $self = shift;
  return ($self->category || '') eq 'session';
}

sub is_user {
  my $self = shift;
  return ($self->category || '') eq 'user';
}

sub is_group {
  my $self = shift;
  return ($self->category || '') eq 'group';
}

sub is_external {
  my $self = shift;
  return $self->is_session || $self->is_user || $self->is_group ? 1 : 0;
}

#================================#
#   Audit/modification methods   #
#================================#

sub is_deleted {
  my $self = shift;
  return $self->{'_deleted'};
}

sub mark_clean {
  my $self = shift;
  $self->{'_altered'} = 0;
  $self->{'_deleted'} = 0;
}

sub mark_deleted {
  my $self = shift;
  $self->{'_deleted'} = 1;
  $self->{'_altered'} = 1;
}

sub mark_altered {
  my $self = shift;
  $self->{'_altered'} = 1;
}

sub is_altered {
  my $self = shift;
  return $self->{'_altered'};
}

sub _guess_views {
  my ( $self ) = @_;
  
  my $positional    = 0;
  my $nonpositional = 0;
  
  for my $cs (@{ $self->coord_systems() }) {
    # assume genomic coordinate systems are always positional
    if ( is_genomic($cs) || $cs->name eq 'toplevel' ) {
      $positional = 1;
    }
    # assume gene coordinate systems are always non-positional
    elsif ( $GENE_COORDS{ $cs->name } ) {
      $nonpositional = 1;
    } else {
      $positional = 1;
      $nonpositional = 1;
    }
  }
  
  my @views = ();
  if ( $positional ) {
    push @views, 'cytoview', 'contigviewbottom';
  }
  if ( $nonpositional ) {
    push @views, 'Gene/ExternalData', 'Transcript/ExternalData';
  }
  
  return \@views;
}

1;
