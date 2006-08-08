package Bio::EnsEMBL::GlyphSet::matepairs;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Bad mate pairs"; }

## Retrieve all BAC map clones - these are the clones in the
## subset "matepairs" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_matepairs")

sub features {
  my ($self) = @_;
  my $container_length = $self->{'container'}->length();
  my $max_full_length  = $self->{'config'}->get( "matepairs", 'full_threshold' ) || 200000000;
  my @T = grep { $_->seq_region_end - $_->seq_region_start < 5e5 } @{  $self->{'container'}->get_all_MiscFeatures( 'matepairs' ) };
  return \@T;
}

## If bac map clones are very long then we draw them as "outlines" as
## we aren't convinced on their quality...

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

## Link back to this page centred on the map fragment

## Create the zmenu...
## Include each accession id separately

sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $VCS = $self->{'container'}->start()-1;
    my $zmenu = { 
        'caption' => "Bad mate pairs",
        "01:status: ".$f->get_scalar_attribute('status') => '',
        "02:length: @{[$f->length]} bps" => '',
        "03:bps: @{[$f->seq_region_start]}-@{[$f->seq_region_end]} bps" => '',
    };
}

sub colour {
    my ($self, $f) = @_;
    my $state = $f->get_scalar_attribute('status');
    return $self->{'colours'}{"col_$state"},
           $self->{'colours'}{"lab_$state"} ;
}

sub image_label {
    my ($self, $f ) = @_;
  my $label = "@{[$f->get_scalar_attribute('name')]}";
    return ( $label,'overlaid');
}


1;
