package Bio::EnsEMBL::GlyphSet::cloneset_1mb;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "1mb cloneset"; }

## Retrieve all BAC map clones - these are the clones in the
## subset "bac_map" - if we are looking at a long segment then we only
## retrieve accessioned clones ("acc_bac_map")

sub features {
    my ($self) = @_;
    return $self->{'container'}->get_all_MiscFeatures( 'cloneset_1mb' );
}

sub colour {
  my ($self, $f) = @_;
  my $type = $f->get_scalar_attribute('method');
  return $self->{'colours'}{"col_$type"}||'grey50', $self->{'colours'}{"lab_$type"}||'black', '';
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
  my ($self, $f ) = @_;
  return (qq(@{[$f->get_scalar_attribute('name')]}),'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
  my ($self, $f ) = @_;
  return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=@{[$f->get_scalar_attribute('name')]}";
}

sub tag {
  my ($self, $f) = @_; 
  my @result = (); 
  my $offset = $self->{'container'}->start - 1 ;
  if( $f->get_scalar_attribute('fish') ) {
    push @result, {
      'style' => 'left-triangle',
      'colour' => $self->{'colours'}{"fish_tag"},
    };
  }
  return @result;
}

## Create the zmenu...
## Include each accession id separately
sub zmenu {
    my ($self, $f ) = @_;
    return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
    my $zmenu = { 
        'caption' => "Clone: @{[$f->get_scalar_attribute('name')]}",
        "01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}" => '',
        "02:length: @{[$f->length]} bps" => '',
        "03:Centre on clone:" => $self->href($f),
    };
    foreach(@{$f->get_all_attribute_values('sanger_project')}) {
        $zmenu->{"11:Synonym: $_" } = '';
    }
    foreach(@{$f->get_all_attribute_values('embl_acc')}) { $zmenu->{"12:EMBL: $_" } = ''; }
    (my $state = $f->get_scalar_attribute('state'))=~s/^\d\d://;
    $zmenu->{"13:Organisation: @{[$f->get_scalar_attribute('org')]}"     } = '' if $f->get_scalar_attribute('org');
    $zmenu->{"14:State: $state"                                          } = '' if $state;
    $zmenu->{"18:FISH:  @{[$f->get_scalar_attribute('fish')]}"           } = '' if $f->get_scalar_attribute('fish');    
    $zmenu->{"80:Positioned by: @{[$f->get_scalar_attribute('method')]}" } = '';
    return $zmenu;
}

1;
