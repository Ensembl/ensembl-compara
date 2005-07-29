package Bio::EnsEMBL::GlyphSet::fosmid_map;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_simple;
@ISA = qw(Bio::EnsEMBL::GlyphSet_simple);

sub my_label { return "Fosmid map"; }

## Retrieve all Fosmid clones - these are the clones in the

sub features {
    my ($self) = @_;
    my @sorted =  
        map { $_->[1] }
        sort { $a->[0] <=> $b->[0] }
        map { [$_->seq_region_start , $_] }
        grep { $_->seq_region_end - $_->seq_region_start > 3e4 }
        @{$self->{'container'}->get_all_MiscFeatures( 'fosmid_map' )};
    return \@sorted;
}

## Return the image label and the position of the label
## (overlaid means that it is placed in the centre of the
## feature.

sub image_label {
  my ($self, $f ) = @_;
  return ("@{[$f->get_scalar_attribute('name')]}",'overlaid');
}

## Link back to this page centred on the map fragment

sub href {
    my ($self, $f ) = @_;
    return "/@{[$self->{container}{_config_file_name_}]}/$ENV{'ENSEMBL_SCRIPT'}?mapfrag=@{[$f->get_scalar_attribute('name')]}";
}

sub tag {
    my ($self, $f) = @_; 
    my @result = (); 
    my ($s,$e) = $self->sr2slice( $f->get_scalar_attribute('inner_start'), $f->get_scalar_attribute('inner_end') );
    if( $s && $e ){
      push @result, {
        'style'  => 'rect',
        'colour' => $f->{'_colour_flag'} || $self->{'colours'}{"col"},
        'start'  => $s,
        'end'    => $e
      };
    }
    return @result;
}
## Create the zmenu...
## Include each accession id separately

sub zmenu {
  my ($self, $f ) = @_;
  return if $self->{'container'}->length() > ( $self->{'config'}->get( $self->check(), 'threshold_navigation' ) || 2e7) * 1000;
  return { 
    qq(caption)                                            => qq(Fosmid: @{[$f->get_scalar_attribute('name')]}),
    qq(01:bp: @{[$f->seq_region_start]}-@{[$f->seq_region_end]}) => '',
    qq(02:length: @{[$f->length]} bps)                     => '',
    qq(03:Centre on fosmid:)                                => $self->href($f),
  };
}

1;
