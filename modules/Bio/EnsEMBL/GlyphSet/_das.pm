package Bio::EnsEMBL::GlyphSet::_das;

use strict;
use base qw(Bio::EnsEMBL::GlyphSet_simple);
use Bio::EnsEMBL::ExternalData::DAS::Stylesheet;

use Data::Dumper;

sub _das_type {  return 'das'; }

sub features       { 
  my $self = shift;
  
  ## Fetch all the das features...
  unless( $self->cache('das_features') ) {
    # Query by slice:
    $self->cache('das_features', $self->cache('das_coord')->fetch_Features( $self->{'container'} )||{} );
  }
  
  my $data = $self->cache('das_features');
  
  for my $logic_name ( @{ $self->my_config('logicnames') } ) {
    local $Data::Dumper::Indent = 1;    
    my $stylesheet = $data->{ $logic_name }{ 'stylesheet' } || Bio::EnsEMBL::ExternalData::DAS::Stylesheet->new();
    my @features   = @{ $data->{ $logic_name }{ 'features' } };
    my @errors     = @{ $data->{ $logic_name }{ 'errors'   } };
    
warn "
================================================================================
";
    warn join ": ", $self->my_config('name'), keys %{$data->{$logic_name}};
    warn sprintf "DAS / %s / %d features / %d errors / %s", $logic_name, scalar @features, scalar @errors, $stylesheet;
    
    warn Dumper( $stylesheet );

    for my $error ( @errors ) { warn "ERROR: $error"; }
    for my $f ( @features ) { 
      warn sprintf "
Feature:   %s
  id:      %s
  label:   %s
  type:    %s
  seqname: %s
  region:  %s
  start:   %d
  end:     %d
  strand:  %d
  start:   %d
  end:     %d
  strand:  %d
  cat:     %s
  score:   %s
  notes:   %s
  links:   %s
  groups:  %s
",
      $f->id,
      $f->display_id,
      $f->display_label,
      $f->type,
      $f->seqname,
      $f->seq_region_name,
      $f->seq_region_start,
      $f->seq_region_end,
      $f->seq_region_strand,
      $f->start,
      $f->end,
      $f->strand,
      $f->type_category,
      $f->score,
      join( "\n           ", @{$f->notes} ),
      join( "\n           ", map { sprintf "%-50.50s: %s", $_->{txt}, $_->{href} } @{$f->links} ),
      join( "\n           ", map { sprintf "%-30.30s: %s", $_->{group_id}, $_->{group_type} } @{$f->groups} );
    }
warn "
================================================================================
";
    
  }
  
  return [];
}

sub colour_key {
  my( $self, $f ) = @_;
  return '';
}

sub feature_label {
  return undef;
}

sub title {
  my( $self, $f ) = @_;
  return 'DAS'
}

sub href {
  my ($self, $f ) = @_;
  return undef;
}

sub tag {
  my ($self, $f ) = @_;
  return; 
}
1;
