# $Id$

package EnsEMBL::Web::ZMenu::Das;

use strict;

use HTML::Entities qw(encode_entities decode_entities);
use XHTML::Validator;
use Bio::EnsEMBL::ExternalData::DAS::Coordinator;
use EnsEMBL::Web::RegObj;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  
  my $object      = $self->object;
  my $logic_name  = $object->param('logic_name') || die 'No logic name in params';
  my $feature_id  = $object->param('feature_id');
  my $group_id    = $object->param('group_id');
  my $start       = $object->param('start');
  my $end         = $object->param('end');
  my $strand      = $object->param('strand');
  my $click_start = $object->param('click_start');
  my $click_end   = $object->param('click_end');
  my %das         = %{$ENSEMBL_WEB_REGISTRY->get_all_das($object->species)};
  my $slice       = $object->can('slice') ? $object->slice : $object->get_slice_object->Obj;
  my %strand_map  = ( 1 => '+', -1 => '-' );
  
  my $coordinator = new Bio::EnsEMBL::ExternalData::DAS::Coordinator(
    -sources => [ $das{$logic_name} ],
    -proxy   => $object->species_defs->ENSEMBL_WWW_PROXY,
    -noproxy => $object->species_defs->ENSEMBL_NO_PROXY,
    -timeout => $object->species_defs->ENSEMBL_DAS_TIMEOUT
  );
  
  my $features = $coordinator->fetch_Features($slice, ( feature => $feature_id, group => $group_id ));
  
  return unless $features && $features->{$logic_name};
  
  my $validator = new XHTML::Validator('extended');
  my $id        = $feature_id || $group_id || 'default';
  
  $strand = $strand_map{$strand} || '0';
  
  $self->caption($id);
  
  foreach (keys %{$features->{$logic_name}->{'features'}}) {
    my $objects = $features->{$logic_name}->{'features'}->{$_}->{'objects'};
    
    next unless scalar @$objects;
    
    my $nearest_feature = 1;    # Initialise so it exists
    my $nearest         = 1e12; # Arbitrary large number
    my ($left, $right, $min, @feat);
    
    foreach (@$objects) {
      $left  = $_->seq_region_start - $click_start;
      $right = $click_end - $_->seq_region_end;
      
      # If both are 0 or positive, feature is inside the click region.
      # If both are negative, click is inside the feature.
      if (($left >= 0 && $right >= 0) || ($left < 0 && $right < 0)) {
        push @feat, $_;
        
        $nearest_feature = undef;
      } elsif ($nearest_feature) {
        $min = [ sort { $a <=> $b } abs($left), abs($right) ]->[0];
        
        if ($min < $nearest) {
          $nearest_feature = $_;
          $nearest = $min;
        }
      }
    }
    
    # Return the nearest feature if it's inside two click widths
    push @feat, $nearest_feature if $nearest_feature && $nearest < 2 * ($click_end - $click_start);
    
    foreach (@feat) {
      my $label  = $_->display_label;
      my $method = $_->method_label; 
      my $score  = $_->score; 
      
      if ($label ne $id || scalar @feat > 1) {
        $label = "Nearest feature: $label" if $nearest_feature;
        
        $self->add_subheader($label);
      }
      
      $self->add_entry({ type => 'Type:',   label_html => $_->type_label });
      $self->add_entry({ type => 'Method:', label_html => $method }) if $method;
      $self->add_entry({ type => 'Start:',  label_html => $_->seq_region_start });
      $self->add_entry({ type => 'End:',    label_html => $_->seq_region_end });
      $self->add_entry({ type => 'Strand:', label_html => $strand });
      $self->add_entry({ type => 'Score:',  label_html => $score }) if $score;
      
      $self->add_entry({ label_html => $_->{'txt'}, link => decode_entities($_->{'href'}), extra => { external => ($_->{'href'} !~ /^http:\/\/www.ensembl.org/) } }) for @{$_->links};
      $self->add_entry({ label_html => $validator->validate($_) ? encode_entities($_) : $_ }) for map decode_entities($_), @{$_->notes};
    }
  }
}

1;
